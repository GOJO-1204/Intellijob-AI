require "test_helper"

class MatchJobsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  READY = { resume_text: "Ruby developer", target_role: "Backend" }.freeze

  def make_profile(attrs = READY)
    user = User.create!(email: "match-#{SecureRandom.hex(4)}@example.com", password: "password123")
    user.profile.tap { |profile| profile.update!(attrs) }
  end

  def make_job(number, overrides = {})
    Job.create!({ url: "https://example.com/m/#{number}", title: "Job #{number}", company: "Acme",
                  posted_at: 1.day.ago, remote: true, source: "remotive", embedding: [ 1.0, 0.0 ] }.merge(overrides))
  end

  def application_for(profile, job)
    JobApplication.find_by(user_id: profile.user_id, job_id: job.id)
  end

  def count_for(profile)
    JobApplication.where(user_id: profile.user_id).count
  end

  # Fake Matcher. The handler is a lambda that gets the profile and returns [ [ job, score ], ... ].
  def with_matcher(handler)
    original = Matcher.method(:call)
    seen = []
    Matcher.define_singleton_method(:call) do |profile, **_options|
      seen << profile.id
      handler.call(profile)
    end
    yield seen
  ensure
    Matcher.define_singleton_method(:call, original)
  end

  # Runs the job and returns the captured log text.
  def run_job(*args)
    original = Rails.logger
    io = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(io)
    MatchJobsJob.perform_now(*args)
    io.string
  ensure
    Rails.logger = original
  end

  test "creates a matched application with the score for every pair" do
    profile = make_profile
    first = make_job(1)
    second = make_job(2)
    with_matcher(->(_profile) { [ [ first, 0.9 ], [ second, 0.4 ] ] }) { run_job(profile.user_id) }

    assert_equal 2, count_for(profile)
    assert_equal [ "matched", "matched" ], [ first, second ].map { |job| application_for(profile, job).status }
    assert_in_delta 0.9, application_for(profile, first).score, 0.0001
    assert_in_delta 0.4, application_for(profile, second).score, 0.0001
  end

  test "never overwrites an existing application" do
    profile = make_profile
    jobs = [ make_job(1), make_job(2), make_job(3) ]
    statuses = [ "dismissed", "saved", "applied" ]
    jobs.zip(statuses).each do |job, status|
      JobApplication.create!(user_id: profile.user_id, job: job, status: status, score: 0.1)
    end
    log = with_matcher(->(_profile) { jobs.map { |job| [ job, 0.99 ] } }) { run_job(profile.user_id) }

    assert_equal 3, count_for(profile)
    assert_equal statuses, jobs.map { |job| application_for(profile, job).status }
    jobs.each { |job| assert_in_delta 0.1, application_for(profile, job).score, 0.0001 }
    assert_includes log, "matched=3 created=0"
  end

  test "running twice creates no second row" do
    profile = make_profile
    jobs = [ make_job(1), make_job(2) ]
    handler = ->(_profile) { jobs.map { |job| [ job, 0.5 ] } }
    first_log, second_log = with_matcher(handler) { [ run_job(profile.user_id), run_job(profile.user_id) ] }

    assert_equal 2, count_for(profile)
    assert_includes first_log, "created=2"
    assert_includes second_log, "created=0"
  end

  test "the log line has the counts" do
    profile = make_profile
    jobs = [ make_job(1), make_job(2), make_job(3) ]
    JobApplication.create!(user_id: profile.user_id, job: jobs.first, status: "saved", score: 0.2)
    log = with_matcher(->(_profile) { jobs.map { |job| [ job, 0.5 ] } }) { run_job(profile.user_id) }

    assert_includes log, "profile=#{profile.id}: matched=3 created=2"
  end

  test "skips profiles that are not ready" do
    ready = make_profile
    not_ready = [ make_profile({ resume_text: "Ruby developer" }), make_profile({ target_role: "Backend" }),
                  make_profile({ resume_text: "", target_role: "" }) ]

    with_matcher(->(_profile) { [] }) do |seen|
      run_job
      assert_includes seen, ready.id
      not_ready.each { |profile| assert_not_includes seen, profile.id }
    end
  end

  test "with a user_id it handles only that user and with nil every ready profile" do
    first = make_profile
    second = make_profile

    with_matcher(->(_profile) { [] }) do |seen|
      run_job(first.user_id)
      assert_equal [ first.id ], seen
      seen.clear
      run_job
      assert_includes seen, first.id
      assert_includes seen, second.id
    end
  end

  test "one failing profile does not stop the others" do
    bad = make_profile
    good = make_profile
    job = make_job(1)
    handler = lambda do |profile|
      raise "boom secret" if profile.id == bad.id
      [ [ job, 0.8 ] ]
    end
    log = with_matcher(handler) { run_job }

    assert_equal 1, count_for(good)
    assert_equal 0, count_for(bad)
    assert_includes log, "profile failed: RuntimeError"
    assert_not_includes log, "boom secret"
  end

  test "creates no applications when the Matcher returns nothing" do
    profile = make_profile
    log = with_matcher(->(_profile) { [] }) { run_job(profile.user_id) }

    assert_equal 0, count_for(profile)
    assert_includes log, "matched=0 created=0"
  end

  test "the real Matcher gives scores for embedded recent jobs" do
    profile = make_profile(READY.merge(embedding: [ 1.0, 0.0 ]))
    same = make_job(1)
    diagonal = make_job(2, embedding: [ 1.0, 1.0 ])
    run_job(profile.user_id)

    assert_equal 2, count_for(profile)
    assert_in_delta 1.0, application_for(profile, same).score, 0.0001
    assert_in_delta Math.sqrt(0.5), application_for(profile, diagonal).score, 0.0001
    assert_equal [ "matched" ], JobApplication.where(user_id: profile.user_id).distinct.pluck(:status)
  end

  test "the real Matcher gives a profile without an embedding no applications" do
    profile = make_profile
    make_job(1)
    log = nil

    assert_nothing_raised { log = run_job(profile.user_id) }
    assert_equal 0, count_for(profile)
    assert_includes log, "matched=0 created=0"
    assert_not_includes log, "failed"
  end
end
