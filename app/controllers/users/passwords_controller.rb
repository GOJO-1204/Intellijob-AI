class Users::PasswordsController < Devise::PasswordsController
  include RateLimitKeys
  include RateLimitedResponse

  rate_limit to: 10, within: 1.hour, store: RATE_LIMIT_STORE, only: :create, name: "reset-ip",
             with: -> { rate_limited("Too many password reset requests. Please try again in an hour.") }
  rate_limit to: 3, within: 1.hour, store: RATE_LIMIT_STORE, only: :create, name: "reset-email",
             by: :email_or_ip_key,
             with: -> { rate_limited("Too many password reset requests. Please try again in an hour.") }
end
