class Job < ApplicationRecord
  has_many :job_applications, dependent: :destroy

  scope :recent, -> { where(posted_at: 30.days.ago..) }

  # String: title + company + description, used for the embedding.
  def embedding_text
    [ title, company, description ].compact_blank.join("\n")
  end
end
