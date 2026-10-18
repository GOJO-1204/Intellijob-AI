class ProfilesController < ApplicationController
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
    return if @profile&.resume_text.present?

    redirect_to new_profile_path, alert: "Please upload a resume with readable text."
  end

  private

  def resume_param
    params.fetch(:profile, {}).permit(:resume)[:resume]
  end

  def rerender(message)
    flash.now[:alert] = message
    render :new, status: :unprocessable_entity
  end
end
