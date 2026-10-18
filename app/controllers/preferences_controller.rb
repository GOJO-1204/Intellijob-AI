class PreferencesController < ApplicationController
  before_action :set_profile

  def edit
    @suggested = SkillExtractor.call(@profile.resume_text)
  end

  def update
    @profile.assign_attributes(preference_params.merge(target_skills: skills_from_params, embedding: nil))
    if @profile.save(context: :preferences)
      EmbedRecordsJob.perform_later
      redirect_to dashboard_path, notice: "Preferences saved."
    else
      @suggested = SkillExtractor.call(@profile.resume_text)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_profile
    @profile = current_user.profile
    return if @profile&.resume_text.present?

    redirect_to new_profile_path, alert: "Please upload your resume first."
  end

  def preference_params
    params.require(:profile).permit(:target_role, :location, :remote, :salary_min, :experience_level, :alert_frequency)
  end

  def skills_from_params
    picked = Array(params.dig(:profile, :target_skills)).grep(String)
    extra = params.dig(:profile, :extra_skills).to_s.split(",")
    (picked + extra).map { |s| s.downcase.strip.first(50) }.reject(&:empty?).uniq.first(30)
  end
end
