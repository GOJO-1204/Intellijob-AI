class Users::PasswordsController < Devise::PasswordsController
  include RateLimitKeys

  rate_limit to: 10, within: 1.hour, store: RATE_LIMIT_STORE, only: :create, name: "reset-ip"
  rate_limit to: 3, within: 1.hour, store: RATE_LIMIT_STORE, only: :create, name: "reset-email",
             by: :email_or_ip_key
end
