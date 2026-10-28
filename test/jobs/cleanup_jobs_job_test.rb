require "test_helper"

class CleanupJobsJobTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "cleanup@example.com", password: "password123")
    @count = 0
  end

  test "old job with only matched applications is deleted with them" do
    job = make_job(posted_at: 40.days.ago)
    make_application(job, "matched")
    CleanupJobsJob.perform_now
    assert_not Job.exists?(job.id)
    assert_equal 0, JobApplication.where(job_id: job.id).count
  end

  test "old job with an applied application is kept with its application" do
    job = make_job(posted_at: 40.days.ago)
    make_application(job, "applied")
    CleanupJobsJob.perform_now
    assert Job.exists?(job.id)
    assert_equal 1, JobApplication.where(job_id: job.id, status: "applied").count
  end

  test "old manual job is kept" do
    job = make_job(posted_at: 40.days.ago, source: "manual")
    make_application(job, "matched")
    CleanupJobsJob.perform_now
    assert Job.exists?(job.id)
    assert_equal 1, JobApplication.where(job_id: job.id).count
  end

  test "recent job with a matched application is kept" do
    job = make_job(posted_at: 5.days.ago)
    make_application(job, "matched")
    CleanupJobsJob.perform_now
    assert Job.exists?(job.id)
    assert_equal 1, JobApplication.where(job_id: job.id).count
  end

  test "old job without applications is deleted and nil posted_at is kept" do
    old_job = make_job(posted_at: 40.days.ago)
    undated_job = make_job(posted_at: nil)
    CleanupJobsJob.perform_now
    assert_not Job.exists?(old_job.id)
    assert Job.exists?(undated_job.id)
  end

  private

  def make_job(posted_at:, source: "seed")
    @count += 1
    Job.create!(title: "Dev #{@count}", company: "Acme", url: "https://example.com/jobs/#{@count}",
                source: source, posted_at: posted_at)
  end

  def make_application(job, status)
    JobApplication.create!(user: @user, job: job, status: status)
  end
end
