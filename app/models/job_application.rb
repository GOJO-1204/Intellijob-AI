class JobApplication < ApplicationRecord
  belongs_to :user
  belongs_to :job

  validates :job_id, uniqueness: { scope: :user_id }

  # Hash form is required: the column is a string, so an array would store integers.
  enum :status, {
    matched: "matched",
    saved: "saved",
    applied: "applied",
    interview: "interview",
    offer: "offer",
    rejected: "rejected",
    dismissed: "dismissed"
  }

  scope :alertable, -> { where(status: :matched, notified_at: nil) }

  before_save :set_applied_at_once

  private

  # Only stamps on the change into "applied", and never overwrites an existing value.
  def set_applied_at_once
    return unless applied? && will_save_change_to_status? && applied_at.nil?

    self.applied_at = Time.current
  end
end
