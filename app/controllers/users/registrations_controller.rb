class Users::RegistrationsController < Devise::RegistrationsController
  include RateLimitedResponse

  rate_limit to: 30, within: 1.hour, store: RATE_LIMIT_STORE, only: :create, name: "signup-ip",
             with: -> { rate_limited("Too many sign up attempts. Please try again in an hour.") }
end
