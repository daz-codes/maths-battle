Rails.application.routes.draw do
  root "home#show"

  resource :session, only: %i[new create destroy]
  resource :registration, only: %i[new create]
  resource :profile, only: %i[edit update]
  resource :topic, only: :update

  get "play/:topic", to: "games#show", as: :play
  # Where the times tables game used to be, still linked from copies kept on devices
  get "times-tables", to: redirect("/play/times-tables")
  resources :attempts, only: %i[create show]
  get "stats(/:topic)", to: "stats#show", as: :stats
  get "s/:share_token", to: "shares#show", as: :share

  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
