class UnsubscribesController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    profile = find_profile
    return render :invalid, status: :not_found unless profile
    @token = token
    render :show
  end

  def create
    if find_profile&.update(alert_frequency: "paused")
      render :create
    else
      render :invalid, status: :not_found
    end
  end

  private

  # to_s means an array or hash param can never raise.
  def token
    params[:token].to_s
  end

  def find_profile
    User.find_signed(token, purpose: :unsubscribe)&.profile
  end
end
