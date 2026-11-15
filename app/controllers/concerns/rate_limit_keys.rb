module RateLimitKeys
  extend ActiveSupport::Concern

  private

  # Lowercased email from the form, or the IP when it is missing or not a plain value.
  def email_or_ip_key
    user = params[:user]
    email = user[:email] if user.respond_to?(:key?)
    email.to_s.strip.downcase.first(254).presence || request.remote_ip
  end
end
