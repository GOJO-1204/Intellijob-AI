require "test_helper"

class JobSourcesAdzunaTest < ActiveSupport::TestCase
  KEYS = [ :title, :company, :url, :description, :location, :remote,
           :salary_min, :source, :external_id, :posted_at ].freeze

  def reply(klass, code, body = "")
    klass.new("1.1", code, "").tap { |res| res.define_singleton_method(:body) { body } }
  end

  def ok(results)
    reply(Net::HTTPOK, "200", { "results" => results }.to_json)
  end

  def result(number = 1, overrides = {})
    { "id" => 4000 + number, "title" => "Rails Developer", "description" => "Build web apps in Rails.",
      "redirect_url" => "https://www.adzuna.in/ad/#{number}", "created" => "2026-11-01T09:30:00Z",
      "salary_min" => 600_000.0, "company" => { "display_name" => "Acme" },
      "location" => { "display_name" => "Bengaluru, Karnataka" } }.merge(overrides)
  end

  # One reply per request, in order. An exception class or instance is raised.
  def with_replies(replies)
    original = Net::HTTP.method(:start)
    seen = []
    Net::HTTP.define_singleton_method(:start) do |*args, **opts, &_block|
      item = replies[seen.size]
      seen << [ args, opts ]
      raise item if item.is_a?(Class) || item.is_a?(Exception)
      item
    end
    yield seen
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end

  def with_credentials(app_id: "test_id", app_key: "SECRETKEY123")
    creds = Rails.application.credentials
    original = creds.method(:dig)
    creds.define_singleton_method(:dig) do |*keys|
      case keys
      when [ :adzuna, :app_id ] then app_id
      when [ :adzuna, :app_key ] then app_key
      else original.call(*keys)
      end
    end
    yield
  ensure
    creds.singleton_class.send(:remove_method, :dig) if creds.singleton_methods.include?(:dig)
  end

  def fetch_with(replies)
    with_credentials { with_replies(replies) { JobSources::Adzuna.fetch } }
  end

  def captured_log
    original = Rails.logger
    io = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end

  test "returns an empty list and makes no request without credentials" do
    [ { app_id: nil, app_key: nil }, { app_id: "test_id", app_key: " " }, { app_id: "", app_key: "k" } ].each do |creds|
      with_credentials(**creds) do
        with_replies([]) do |seen|
          assert_empty JobSources::Adzuna.fetch
          assert_empty seen
        end
      end
    end
  end

  test "makes one request per keyword and maps the results" do
    with_credentials do
      with_replies([ ok([ result(1) ]), ok([ result(2) ]), ok([ result(3) ]) ]) do |seen|
        jobs = JobSources::Adzuna.fetch
        job = jobs.first
        assert_equal 3, seen.size
        assert_equal 3, jobs.size
        assert(seen.all? { |args, opts| args.first == "api.adzuna.com" && opts[:use_ssl] == true })
        assert_equal KEYS.sort, job.keys.sort
        assert_equal [ "Rails Developer", "Acme", "Bengaluru, Karnataka", "adzuna" ],
                     job.values_at(:title, :company, :location, :source)
        assert_equal [ "https://www.adzuna.in/ad/1", "4001", 600_000 ], job.values_at(:url, :external_id, :salary_min)
        assert_kind_of Time, job[:posted_at]
      end
    end
  end

  test "the same url under all keywords appears once" do
    jobs = fetch_with([ ok([ result(1) ]) ] * 3)
    assert_equal [ "https://www.adzuna.in/ad/1" ], jobs.map { |job| job[:url] }
  end

  test "salary_min is a rounded Integer when numeric and nil otherwise" do
    results = [ result(1, "salary_min" => 450_000.6), result(2, "salary_min" => 450_000),
                result(3, "salary_min" => "450000"), result(4, "salary_min" => nil),
                result(5).except("salary_min") ]
    salaries = fetch_with([ ok(results) ] * 3).map { |job| job[:salary_min] }
    assert_equal [ 450_001, 450_000, nil, nil, nil ], salaries
    assert_kind_of Integer, salaries.first
  end

  test "remote is true for remote or work from home in any case" do
    results = [ result(1, "title" => "REMOTE Ruby Developer"),
                result(2, "description" => "Work From Home most days"),
                result(3, "description" => "This role is remote friendly"), result(4),
                result(5, "title" => nil, "description" => nil) ]
    remote = fetch_with([ ok(results) ] * 3).map { |job| job[:remote] }
    assert_equal [ true, true, true, false, false ], remote
  end

  test "skips results without a redirect_url and entries that are not hashes" do
    results = [ "text", nil, 7, result(1), result(2, "redirect_url" => nil),
                result(3, "redirect_url" => " "), result(4).except("redirect_url") ]
    jobs = fetch_with([ ok(results) ] * 3)
    assert_equal [ "https://www.adzuna.in/ad/1" ], jobs.map { |job| job[:url] }
  end

  test "a failed keyword does not stop the other two" do
    replies = [ reply(Net::HTTPInternalServerError, "500"), ok([ result(1) ]), ok([ result(2) ]) ]
    jobs = fetch_with(replies)
    assert_equal [ "https://www.adzuna.in/ad/1", "https://www.adzuna.in/ad/2" ], jobs.map { |job| job[:url] }
  end

  test "a bad body gives an empty list for that keyword" do
    no_results = reply(Net::HTTPOK, "200", { "count" => 0 }.to_json)
    bad_json = reply(Net::HTTPOK, "200", "<html>not json</html>")
    assert_empty fetch_with([ no_results, ok("nope"), bad_json ])
    assert_equal 1, fetch_with([ no_results, bad_json, ok([ result(1) ]) ]).size
  end

  test "a timeout gives an empty list and does not raise" do
    assert_empty fetch_with([ Net::OpenTimeout ] * 3)
  end

  test "the log never contains the app key" do
    http_error = reply(Net::HTTPInternalServerError, "500")
    log = captured_log { fetch_with([ http_error ] * 3) }
    assert_includes log, "HTTP 500"
    assert_not_includes log, "SECRETKEY123"
    log = captured_log { fetch_with([ StandardError.new("failed, app_key=SECRETKEY123") ] * 3) }
    assert_includes log, "StandardError"
    assert_not_includes log, "SECRETKEY123"
  end
end
