class Job < ApplicationRecord
  has_many :job_applications, dependent: :destroy

  scope :recent, -> { where(posted_at: 30.days.ago..) }

  # Job or nil: creates or updates the row matching hash[:url].
  def self.upsert_from(hash)
    return if hash[:url].blank?

    job = find_or_initialize_by(url: hash[:url])
    job.assign_attributes(
      hash.slice(:title, :company, :description, :location, :remote,
                 :salary_min, :source, :external_id, :posted_at)
    )
    job.save
    job
  end

  # String: title + company + description, used for the embedding.
  def embedding_text
    [ title, company, description ].compact_blank.join("\n")
  end
end
