class CleanupJobsJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 500

  def perform
    jobs_deleted = 0
    applications_deleted = 0

    deletable_jobs.in_batches(of: BATCH_SIZE) do |batch|
      ids = batch.pluck(:id)
      apps = jobs = 0
      Job.transaction do
        apps = JobApplication.where(job_id: ids, status: "matched").delete_all
        # Re-checked in SQL: a job that got a saved or applied application meanwhile survives
        jobs = Job.where(id: ids).where("NOT EXISTS (?)", applications_of_job).delete_all
      end
      applications_deleted += apps
      jobs_deleted += jobs
    rescue StandardError => e
      Rails.logger.error("[CleanupJobsJob] batch failed error=#{e.class}")
    end

    Rails.logger.info("[CleanupJobsJob] jobs_deleted=#{jobs_deleted} applications_deleted=#{applications_deleted}")
  end

  private

  # NULL posted_at never matches the range. NULL source is deletable, 'manual' is kept.
  def deletable_jobs
    Job.where(posted_at: ...30.days.ago)
       .where("jobs.source IS DISTINCT FROM ?", "manual")
       .where("NOT EXISTS (?)", applications_of_job.where.not(status: "matched"))
  end

  def applications_of_job
    JobApplication.where("job_applications.job_id = jobs.id")
  end
end
