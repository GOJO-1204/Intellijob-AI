class SendAlertsJob < ApplicationJob
  queue_as :default

  FREQUENCIES = %w[daily weekly].freeze
  LIMIT = 5

  def perform(frequency)
    return unless FREQUENCIES.include?(frequency)

    emailed = 0
    User.joins(:profile).where(profiles: { alert_frequency: frequency }).find_each do |user|
      emailed += 1 if send_alert(user)
    rescue StandardError => e
      Rails.logger.error("SendAlertsJob failed user_id=#{user.id} error=#{e.class}")
    end

    Rails.logger.info("SendAlertsJob #{frequency}: emailed #{emailed} users")
  end

  private

  # Returns true when an email was enqueued for this user.
  def send_alert(user)
    apps = user.job_applications.alertable.includes(:job).order(score: :desc).limit(LIMIT).to_a
    return false if apps.empty?

    ids = apps.map(&:id)
    JobAlertMailer.new_matches(user, apps).deliver_later
    # Marked right after enqueue, not after delivery.
    JobApplication.where(id: ids).update_all(notified_at: Time.current)
    true
  end
end
