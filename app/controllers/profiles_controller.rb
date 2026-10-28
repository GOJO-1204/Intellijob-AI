class ProfilesController < ApplicationController
  ANALYSIS_WINDOW = 90 # seconds the results page may keep checking for AI tips

  def new; end

  def create
    resume = resume_param
    return rerender("Please choose a resume file.") if resume.blank?

    profile = current_user.profile || current_user.build_profile
    profile.resume = resume
    profile.save!
    profile.update!(resume_text: ResumeParser.call(profile.resume))
    ResumeAnalysisJob.perform_later(profile.id)
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

  # Finished means ai_suggestions is filled in. Otherwise the clock runs from
  # the moment the resume file was attached, so other profile saves cannot reset it.
  def analysis_seconds_left(profile)
    return 0 if Array(profile.ai_suggestions).any?

    started = profile.resume_attachment&.created_at
    return 0 if started.nil?

    [ (ANALYSIS_WINDOW - (Time.current - started)).ceil, 0 ].max
  end

  def resume_param
    params.fetch(:profile, {}).permit(:resume)[:resume]
  end

  def rerender(message)
    flash.now[:alert] = message
    render :new, status: :unprocessable_entity
  end
end
