class UnsubscribesController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    user = User.find_signed(params[:token], purpose: :unsubscribe)
    profile = user&.profile
    @paused = profile.present? && profile.update(alert_frequency: "paused")
    render :show, status: :not_found unless @paused
  end
end
