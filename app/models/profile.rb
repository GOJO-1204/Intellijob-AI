class Profile < ApplicationRecord
  RESUME_TYPES = [
    "application/pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  ].freeze
  MAX_RESUME_SIZE = 5.megabytes

  belongs_to :user
  has_one_attached :resume

  validate :resume_is_pdf_or_docx_under_limit

  scope :ready, -> {
    where.not(resume_text: [ nil, "" ]).where.not(target_role: [ nil, "" ])
  }

  # String: role + skills + resume text, used for the embedding.
  def embedding_text
    [ target_role, Array(target_skills).join(", "), resume_text ].compact_blank.join("\n")
  end

  # Boolean
  def ready_for_matching?
    resume_text.present? && target_role.present?
  end

  private

  def resume_is_pdf_or_docx_under_limit
    return unless resume.attached?

    unless RESUME_TYPES.include?(resume.blob.content_type)
      errors.add(:resume, "must be a PDF or DOCX file")
    end

    if resume.blob.byte_size >= MAX_RESUME_SIZE
      errors.add(:resume, "must be under 5 MB")
    end
  end
end
