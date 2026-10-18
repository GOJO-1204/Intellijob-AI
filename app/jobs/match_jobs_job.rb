class MatchJobsJob < ApplicationJob
  # user_id nil = every ready profile; otherwise only that user's ready profile.
  def perform(user_id = nil)
    profiles = Profile.ready
    profiles = profiles.where(user_id: user_id) unless user_id.nil?

    profiles.find_each { |profile| match_profile(profile) }
  end

  private

  # Rescued per profile so one failure never stops the others. Logs the error CLASS only.
  def match_profile(profile)
    pairs = Matcher.call(profile)
    created = 0

    pairs.each do |job, score|
      application = JobApplication.find_or_create_by(user_id: profile.user_id, job_id: job.id) do |new_application|
        # Block runs only on create, so existing rows keep their status and score.
        new_application.status = "matched"
        new_application.score = score
      end
      created += 1 if application.previously_new_record?
    end

    Rails.logger.info("[MatchJobsJob] profile=#{profile.id}: matched=#{pairs.size} created=#{created}")
  rescue StandardError => e
    Rails.logger.warn("[MatchJobsJob] profile failed: #{e.class}")
  end
end
