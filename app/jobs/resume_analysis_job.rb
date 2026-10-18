require "pdf/reader"

class ResumeAnalysisJob < ApplicationJob
  queue_as :default

  def perform(profile_id)
    profile = Profile.find_by(id: profile_id)
    return if profile.nil? || profile.resume_text.blank?

    result = ResumeAnalyzer.new(profile.resume_text, target_skills: profile.target_skills, page_count: page_count(profile)).call
    profile.update!(ats_score: result[:score], ats_feedback: { checks: result[:checks], shortcomings: result[:shortcomings] })
    profile.update!(ai_suggestions: ResumeAiReviewer.new(profile.resume_text, target_role: profile.target_role).call)
  end

  private

  def page_count(profile)
    return unless profile.resume.attached? && profile.resume.blob.content_type == ResumeParser::PDF_TYPE

    PDF::Reader.new(StringIO.new(profile.resume.download)).page_count
  rescue StandardError
    nil
  end
end
