require "test_helper"

class FetchJobsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  FakeSource = Struct.new(:name, :hashes, :error, keyword_init: true) do
    def fetch
      raise error if error
      hashes
    end
  end

  def hash_for(number, overrides = {})
    { title: "Job #{number}", company: "Acme", url: "https://example.com/fetch/#{number}",
      description: "Text", location: "Pune", remote: true, salary_min: nil,
      source: "fake", external_id: number.to_s, posted_at: Time.utc(2026, 11, 1) }.merge(overrides)
  end

  def fake_source(name, *hashes)
    FakeSource.new(name: name, hashes: hashes)
  end

  def failing(name, message = "boom secret")
    FakeSource.new(name: name, error: RuntimeError.new(message))
  end

  # Runs the job with fake sources and returns the captured log text.
  def run_job(*sources)
    original_sources = JobSources.method(:all)
    original_logger = Rails.logger
    log = StringIO.new
    JobSources.define_singleton_method(:all) { sources }
    Rails.logger = ActiveSupport::Logger.new(log)
    FetchJobsJob.perform_now
    log.string
  ensure
    JobSources.define_singleton_method(:all, original_sources)
    Rails.logger = original_logger
  end

  test "saves the jobs of every source and queues EmbedRecordsJob once" do
    before = Job.count
    run_job(fake_source("FakeA", hash_for(1), hash_for(2)), fake_source("FakeB", hash_for(3)))

    assert_equal before + 3, Job.count
    assert_enqueued_with(job: EmbedRecordsJob)
    assert_enqueued_jobs 1, only: EmbedRecordsJob
  end

  test "the log has the counts per source" do
    log = run_job(fake_source("FakeA", hash_for(1), hash_for(2)), fake_source("FakeB", hash_for(3)))

    assert_includes log, "FakeA: fetched=2 saved=2 skipped=0"
    assert_includes log, "FakeB: fetched=1 saved=1 skipped=0"
  end

  test "a hash with a blank url is skipped and creates no row" do
    before = Job.count
    hashes = [ hash_for(1), hash_for(2, url: ""), hash_for(3, url: nil), hash_for(4, url: "  ") ]
    log = run_job(fake_source("FakeA", *hashes))

    assert_equal before + 1, Job.count
    assert_includes log, "FakeA: fetched=4 saved=1 skipped=3"
  end

  test "the same url twice leaves one row and counts both as saved" do
    before = Job.count
    log = run_job(fake_source("FakeA", hash_for(1), hash_for(1, title: "Changed")))

    assert_equal before + 1, Job.count
    assert_equal "Changed", Job.find_by(url: hash_for(1)[:url]).title
    assert_includes log, "FakeA: fetched=2 saved=2 skipped=0"
  end

  test "a failing source does not stop the other source" do
    before = Job.count
    run_job(failing("FakeA"), fake_source("FakeB", hash_for(1), hash_for(2)))
    assert_equal before + 2, Job.count

    log = run_job(fake_source("FakeA", hash_for(3)), failing("FakeB"))
    assert_equal before + 3, Job.count
    assert_includes log, "FakeA: fetched=1 saved=1 skipped=0"
  end

  test "the failure log has only the error class" do
    log = run_job(failing("FakeA", "boom secret"), fake_source("FakeB"))

    assert_includes log, "FakeA failed: RuntimeError"
    assert_not_includes log, "boom secret"
  end

  test "a source that returns nothing creates no rows" do
    before = Job.count
    log = run_job(fake_source("FakeA"))

    assert_equal before, Job.count
    assert_includes log, "FakeA: fetched=0 saved=0 skipped=0"
  end

  test "still queues EmbedRecordsJob when every source fails" do
    run_job(failing("FakeA"), failing("FakeB"))
    assert_enqueued_jobs 1, only: EmbedRecordsJob
  end

  test "still queues EmbedRecordsJob when every source returns nothing" do
    run_job(fake_source("FakeA"), fake_source("FakeB"))
    assert_enqueued_jobs 1, only: EmbedRecordsJob
  end
end
