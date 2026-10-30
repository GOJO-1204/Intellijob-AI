Rails.application.routes.draw do
  devise_for :users

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
  resource :dashboard, only: :show, controller: "dashboard"
  resource :profile, only: %i[new create show]
  resource :preferences, only: %i[edit update]
    resources :matches, only: :index
      resources :job_applications, only: %i[new create update]
  get "unsubscribe/:token", to: "unsubscribes#show", as: :unsubscribe
  get "privacy", to: "pages#privacy", as: :privacy
  get "terms", to: "pages#terms", as: :terms
end
