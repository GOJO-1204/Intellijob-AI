class DashboardStats
  def self.call(user)
    applications = user.job_applications
    {
      counts: counts(applications),
      avg_score: avg_score(applications),
      applied_this_week: applications.where(applied_at: 7.days.ago..).count
    }
  end

  def self.counts(applications)
    grouped = applications.group(:status).count
    JobApplication.statuses.keys.index_with { |status| grouped.fetch(status, 0) }
  end

  def self.avg_score(applications)
    average = applications.where.not(status: :dismissed).where.not(score: nil).average(:score)
    average&.to_f&.round(2)
  end

  private_class_method :counts, :avg_score
end
