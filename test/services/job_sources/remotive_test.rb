require "test_helper"

class JobSourcesRemotiveTest < ActiveSupport::TestCase
  KEYS = [ :title, :company, :url, :description, :location, :remote,
           :salary_min, :source, :external_id, :posted_at ].freeze

  def reply(klass, code, body = "")
    klass.new("1.1", code, "").tap { |res| res.define_singleton_method(:body) { body } }
  end

  def ok(jobs)
    reply(Net::HTTPOK, "200", { "jobs" => jobs }.to_json)
  end

  def job_hash(overrides = {})
    { "id" => 123, "url" => "https://remotive.com/jobs/1", "title" => "Rails Developer",
      "company_name" => "Acme", "description" => "<p>Build things.</p>",
      "candidate_required_location" => "Worldwide",
      "publication_date" => "2026-11-01T10:00:00" }.merge(overrides)
  end

  # Every request gets the same reply. An exception class or instance is raised.
  def with_reply(item)
    original = Net::HTTP.method(:start)
    seen = []
    Net::HTTP.define_singleton_method(:start) do |*args, **opts, &_block|
      seen << [ args, opts ]
      raise item if item.is_a?(Class) || item.is_a?(Exception)
      item
    end
    yield seen
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end

  def fetch_with(item)
    with_reply(item) { JobSources::Remotive.fetch }
  end

  test "maps a job to exactly the 10 keys" do
    job = fetch_with(ok([ job_hash ])).first

    assert_equal KEYS.sort, job.keys.sort
    assert_equal [ "Rails Developer", "Acme", "https://remotive.com/jobs/1", "Worldwide" ],
                 job.values_at(:title, :company, :url, :location)
    assert_equal "<p>Build things.</p>", job[:description]
    assert_equal "remotive", job[:source]
    assert_equal true, job[:remote]
    assert_nil job[:salary_min]
    assert_equal "123", job[:external_id]
    assert_kind_of Time, job[:posted_at]
  end

  test "skips jobs whose url is missing or blank" do
    jobs = [ job_hash, job_hash("url" => nil), job_hash("url" => ""), job_hash("url" => "  "), job_hash.except("url") ]
    assert_equal 1, fetch_with(ok(jobs)).size
  end

  test "an empty jobs list gives an empty list" do
    assert_equal [], fetch_with(ok([]))
  end

  test "HTTP errors give an empty list and do not raise" do
    [ [ Net::HTTPInternalServerError, "500" ], [ Net::HTTPTooManyRequests, "429" ] ].each do |klass, code|
      assert_equal [], fetch_with(reply(klass, code)), code
    end
  end

  test "invalid JSON gives an empty list" do
    assert_equal [], fetch_with(reply(Net::HTTPOK, "200", "<html>not json</html>"))
  end

  test "a body without a jobs array gives an empty list" do
    bodies = [ { "error" => "nope" }.to_json, { "jobs" => "none" }.to_json, { "jobs" => { "a" => 1 } }.to_json, "[]" ]
    bodies.each do |body|
      assert_equal [], fetch_with(reply(Net::HTTPOK, "200", body)), body
    end
  end

  test "timeouts and connection errors give an empty list and do not raise" do
    [ Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED ].each do |error|
      assert_equal [], fetch_with(error), error.name
    end
  end

  test "a bad or missing publication_date gives posted_at nil and keeps the job" do
    jobs = fetch_with(ok([ job_hash("publication_date" => "not a date"), job_hash.except("publication_date") ]))

    assert_equal 2, jobs.size
    assert_equal [ nil, nil ], jobs.map { |job| job[:posted_at] }
  end

  test "makes one HTTPS request to remotive.com" do
    with_reply(ok([ job_hash ])) do |seen|
      JobSources::Remotive.fetch
      args, opts = seen.first

      assert_equal 1, seen.size
      assert_equal "remotive.com", args.first
      assert_equal true, opts[:use_ssl]
    end
  end
end
