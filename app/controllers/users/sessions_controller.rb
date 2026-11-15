class Users::SessionsController < Devise::SessionsController
  include RateLimitKeys
  include RateLimitedResponse

  rate_limit to: 30, within: 5.minutes, store: RATE_LIMIT_STORE, only: :create, name: "login-ip",
             with: -> { rate_limited("Too many log in attempts. Please wait 5 minutes and try again.") }
  rate_limit to: 5, within: 5.minutes, store: RATE_LIMIT_STORE, only: :create, name: "login-email",
             by: :email_or_ip_key,
             with: -> { rate_limited("Too many log in attempts. Please wait 5 minutes and try again.") }
end
