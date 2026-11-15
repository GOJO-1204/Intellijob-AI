class Users::RegistrationsController < Devise::RegistrationsController
  rate_limit to: 30, within: 1.hour, store: RATE_LIMIT_STORE, only: :create, name: "signup-ip"
end
