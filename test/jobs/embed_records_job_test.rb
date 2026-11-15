require "test_helper"

class EmbedRecordsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  VECTOR = [ 0.1, 0.2 ].freeze
  READY = { resume_text: "Ruby developer", target_role: "Backend" }.freeze

  def make_job(number, overrides = {})
    Job.create!({ url: "https://example.com/embed/#{number}", title: "Dev #{number}", company: "Acme",
                  description: "Text", posted_at: 1.day.ago }.merge(overrides))
  end

  def make_profile(email, attrs = READY)
    user = User.create!(email: email, password: "password123")
    user.profile.tap { |profile| profile.update!(attrs) }
  end

  def capture_log
    original = Rails.logger
    io = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end

  # Fake Embedder: records every text, raises "boom secret" for the text in fail_on.
  def with_embedder(fail_on: nil)
    original = Embedder.method(:call)
    texts = []
    Embedder.define_singleton_method(:call) do |text|
      texts << text
      raise "boom secret" if text == fail_on
      VECTOR.dup
    end
    yield texts
  ensure
    Embedder.define_singleton_method(:call, original)
  end

  # Guard for the real Embedder: if the model were used, it would raise instead of loading it.
  def with_blocked_model
    original = Embedder.instance_variable_get(:@pipeline)
    Embedder.instance_variable_set(:@pipeline, ->(*_args, **_options) { raise "model must not load" })
    yield
  ensure
    Embedder.instance_variable_set(:@pipeline, original)
  end

  # Returns [ texts the Embedder was called with, log text ].
  def run_job(fail_on: nil)
    result = nil
    with_embedder(fail_on: fail_on) { |texts| result = [ texts, capture_log { EmbedRecordsJob.perform_now } ] }
    result
  end

  test "embeds a recent job without an embedding" do
    job = make_job(1)
    texts, log = run_job

    assert_equal [ job.embedding_text ], texts
    assert_equal [ 0.1, 0.2 ], job.reload.embedding
    assert_includes log, "Job: embedded=1 failed=0"
  end

  test "skips a job that already has an embedding" do
    job = make_job(1, embedding: [ 0.5, 0.5 ])
    texts, _log = run_job

    assert_empty texts
    assert_equal [ 0.5, 0.5 ], job.reload.embedding
  end

  test "skips a job older than 30 days and a job with no posted_at" do
    old = make_job(1, posted_at: 31.days.ago)
    undated = make_job(2, posted_at: nil)
    texts, _log = run_job

    assert_empty texts
    assert_nil old.reload.embedding
    assert_nil undated.reload.embedding
  end

  test "embeds a ready profile without an embedding" do
    profile = make_profile("embed-profile-1@example.com")
    texts, log = run_job

    assert_equal [ profile.embedding_text ], texts
    assert_equal [ 0.1, 0.2 ], profile.reload.embedding
    assert_includes log, "Profile: embedded=1 failed=0"
  end

  test "skips profiles that are not ready or already have an embedding" do
    no_role = make_profile("embed-profile-2@example.com", { resume_text: "Ruby developer" })
    no_resume = make_profile("embed-profile-3@example.com", { target_role: "Backend" })
    empty = make_profile("embed-profile-4@example.com", {})
    done = make_profile("embed-profile-5@example.com")
    done.update_column(:embedding, [ 0.9, 0.9 ])
    texts, _log = run_job

    assert_empty texts
    assert_equal [ nil, nil, nil ], [ no_role, no_resume, empty ].map { |profile| profile.reload.embedding }
    assert_equal [ 0.9, 0.9 ], done.reload.embedding
  end

  test "one failing record does not stop the others" do
    first = make_job(1)
    bad = make_job(2)
    last = make_job(3)
    run_job(fail_on: bad.embedding_text)

    assert_equal [ [ 0.1, 0.2 ], nil, [ 0.1, 0.2 ] ], [ first, bad, last ].map { |job| job.reload.embedding }
  end

  test "the log has the counts and only the error class" do
    make_job(1)
    bad = make_job(2)
    _texts, log = run_job(fail_on: bad.embedding_text)

    assert_includes log, "Job: embedded=1 failed=1"
    assert_includes log, "Profile: embedded=0 failed=0"
    assert_includes log, "record failed: RuntimeError"
    assert_not_includes log, "boom secret"
  end

  test "a profile that fails validation counts as failed and the job does not raise" do
    profile = make_profile("embed-profile-6@example.com")
    profile.update_column(:alert_frequency, "bogus")
    texts, log = run_job

    assert_equal [ profile.embedding_text ], texts
    assert_nil profile.reload.embedding
    assert_includes log, "Profile: embedded=0 failed=1"
  end

  test "a job with blank embedding text fails in the real Embedder" do
    job = make_job(1, title: nil, company: nil, description: nil)
    log = with_blocked_model { capture_log { EmbedRecordsJob.perform_now } }

    assert_nil job.reload.embedding
    assert_includes log, "Job: embedded=0 failed=1"
    assert_includes log, "record failed: ArgumentError"
  end

  test "queues MatchJobsJob once after embedding" do
    make_job(1)
    run_job

    assert_enqueued_with(job: MatchJobsJob)
    assert_enqueued_jobs 1, only: MatchJobsJob
  end

  test "queues MatchJobsJob once when there is nothing to embed" do
    texts, _log = run_job

    assert_empty texts
    assert_enqueued_jobs 1, only: MatchJobsJob
  end

  test "queues MatchJobsJob once even when every record fails" do
    bad = make_job(1)
    run_job(fail_on: bad.embedding_text)

    assert_enqueued_jobs 1, only: MatchJobsJob
  end
end
