Rails.application.routes.draw do
  root "home#show"

  resource :session, only: %i[new create destroy]
  resource :registration, only: %i[new create]
  resource :profile, only: %i[edit update]
  resource :avatar, only: :show
  resource :topic, only: :update
  get "topics", to: "topics#index", as: :topics
  resource :level, only: :update
  resource :streak_freeze, only: :create

  get "play/:topic", to: "games#show", as: :play
  get "learn/:topic/:level", to: "lessons#show", as: :lesson
  post "learn/:topic/:level/done", to: "lesson_completions#create", as: :lesson_completion
  # Where the times tables game used to be, still linked from copies kept on devices
  get "times-tables", to: redirect("/play/times-tables")
  resources :attempts, only: %i[create show]
  get "stats(/:topic)", to: "stats#show", as: :stats
  # Players see their badges as achievements
  resource :achievements, only: :show, controller: :badges
  get "badges", to: redirect("/achievements")
  get "s/:share_token", to: "shares#show", as: :share

  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
