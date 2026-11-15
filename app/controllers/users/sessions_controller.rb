class Users::SessionsController < Devise::SessionsController
  include RateLimitKeys

  rate_limit to: 30, within: 5.minutes, store: RATE_LIMIT_STORE, only: :create, name: "login-ip"
  rate_limit to: 5, within: 5.minutes, store: RATE_LIMIT_STORE, only: :create, name: "login-email",
             by: :email_or_ip_key
end
