class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: :index

  def index
    redirect_to next_step_path if user_signed_in?
  end

  private

  def next_step_path
    profile = current_user.profile
    return new_profile_path if profile&.resume_text.blank?
    return edit_preferences_path if profile.target_role.blank?

    dashboard_path
  end
end
