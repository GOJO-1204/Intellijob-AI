class ProfilesController < ApplicationController
  ANALYSIS_WINDOW = 90 # seconds the results page may keep checking for AI tips

  def new; end

  def create
    resume = resume_param
    return rerender("Please choose a resume file.") if resume.blank?

    profile = current_user.profile || current_user.build_profile
    replace_resume(profile, resume)
    ResumeAnalysisJob.perform_later(profile.id)
    EmbedRecordsJob.perform_later
    redirect_to profile_path
  rescue ResumeParser::Error => e
    rerender(e.message)
  rescue ActiveRecord::RecordInvalid => e
    rerender(e.record.errors.full_messages.to_sentence)
  end

  def show
    @profile = current_user.profile
    if @profile&.resume_text.blank?
      redirect_to new_profile_path, alert: "Please upload a resume with readable text."
      return
    end

    @seconds_left = analysis_seconds_left(@profile)
  end

  private

  # Finished means ai_suggestions is filled in. The clock runs from the resume attachment.
  def analysis_seconds_left(profile)
    return 0 if Array(profile.ai_suggestions).any? || profile.resume_attachment.nil?

    [ (ANALYSIS_WINDOW - (Time.current - profile.resume_attachment.created_at)).ceil, 0 ].max
  end

  # Upload first, then attach, parse and clear old results together.
  # On any failure the database rolls back and the new blob is removed.
  def replace_resume(profile, upload)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: upload.tempfile, filename: upload.original_filename, content_type: upload.content_type
    )
    Profile.transaction do
      profile.update!(resume: blob)
      profile.update!(resume_text: ResumeParser.call(profile.resume),
                      ats_score: nil, ats_feedback: {}, ai_suggestions: [], embedding: nil)
    end
  rescue StandardError
    blob&.purge
    raise
  end

  def resume_param
    params.fetch(:profile, {}).permit(:resume)[:resume]
  end

  def rerender(message)
    flash.now[:alert] = message
    render :new, status: :unprocessable_entity
  end
end
