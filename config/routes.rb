Rails.application.routes.draw do
  root "home#show"

  resource :session, only: %i[new create destroy]
  resource :registration, only: %i[new create]
  resource :profile, only: %i[edit update]

  get "times-tables", to: "times_tables#show", as: :times_tables
  resources :attempts, only: %i[create show]
  get "s/:share_token", to: "shares#show", as: :share

  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
