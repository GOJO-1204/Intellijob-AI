require "test_helper"

class JobTest < ActiveSupport::TestCase
  def job_hash(overrides = {})
    { title: "Rails Developer", company: "Acme", url: "https://example.com/jobs/1",
      description: "Build web apps.", location: "Bengaluru", remote: true, salary_min: 600_000,
      source: "remotive", external_id: "42", posted_at: Time.utc(2026, 11, 1, 10, 0, 0) }.merge(overrides)
  end

  test "creates a job from a full hash and returns a saved Job" do
    before = Job.count
    job = Job.upsert_from(job_hash)

    assert_kind_of Job, job
    assert job.persisted?
    assert_equal before + 1, Job.count
    saved = Job.find(job.id)
    job_hash.each { |key, value| assert_equal value, saved.public_send(key), key.to_s }
  end

  test "returns nil and creates no row when the url is blank" do
    [ nil, "", "   " ].each do |url|
      before = Job.count
      assert_nil Job.upsert_from(job_hash(url: url)), "url #{url.inspect}"
      assert_equal before, Job.count
    end
  end

  test "returns nil and creates no row when the hash has no url key" do
    before = Job.count
    assert_nil Job.upsert_from(job_hash.except(:url))
    assert_equal before, Job.count
  end

  test "calling it twice with the same url keeps one row and the same id" do
    first = Job.upsert_from(job_hash)
    before = Job.count
    second = Job.upsert_from(job_hash)

    assert_equal before, Job.count
    assert_equal first.id, second.id
    assert_equal 1, Job.where(url: job_hash[:url]).count
  end

  test "the second call updates changed fields" do
    first = Job.upsert_from(job_hash)
    Job.upsert_from(job_hash(title: "Senior Rails Developer", salary_min: 700_000))

    first.reload
    assert_equal "Senior Rails Developer", first.title
    assert_equal 700_000, first.salary_min
  end

  test "a different url creates a second row and leaves the first url alone" do
    first = Job.upsert_from(job_hash)
    second = Job.upsert_from(job_hash(url: "https://example.com/jobs/2"))

    assert_not_equal first.id, second.id
    assert_equal "https://example.com/jobs/1", first.reload.url
  end

  test "never assigns an id from the hash" do
    job = Job.upsert_from(job_hash(id: 987_654_321))

    assert_not_equal 987_654_321, job.id
    assert_nil Job.find_by(id: 987_654_321)
  end

  test "never overwrites an existing embedding from the hash" do
    job = Job.upsert_from(job_hash)
    job.update_column(:embedding, [ 0.5, 0.25 ])

    Job.upsert_from(job_hash(title: "New title", embedding: [ 9.0, 9.0 ]))

    assert_equal [ 0.5, 0.25 ], job.reload.embedding
    assert_equal "New title", job.title
  end

  test "ignores unknown keys and created_at without error" do
    job = Job.upsert_from(job_hash(foo: "bar", created_at: 1.year.ago))

    assert job.persisted?
    assert_operator job.created_at, :>, 1.day.ago
  end

  test "recent includes a job posted 1 day ago" do
    job = Job.create!(url: "https://example.com/fresh", posted_at: 1.day.ago)
    assert_includes Job.recent.pluck(:id), job.id
  end

  test "recent excludes a job posted 31 days ago" do
    job = Job.create!(url: "https://example.com/old", posted_at: 31.days.ago)
    assert_not_includes Job.recent.pluck(:id), job.id
  end

  test "recent excludes a job with no posted_at" do
    job = Job.create!(url: "https://example.com/undated", posted_at: nil)
    assert_not_includes Job.recent.pluck(:id), job.id
  end

  test "embedding_text joins title, company and description with newlines" do
    job = Job.new(title: "Dev", company: "Acme", description: "Build things")
    assert_equal "Dev\nAcme\nBuild things", job.embedding_text
  end

  test "embedding_text skips blank parts" do
    assert_equal "Dev\nBuild", Job.new(title: "Dev", company: "  ", description: "Build").embedding_text
    assert_equal "Acme", Job.new(title: nil, company: "Acme", description: "").embedding_text
    assert_equal "", Job.new.embedding_text
  end
end
