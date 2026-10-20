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
  resource :reminder, only: %i[ update destroy ]
  resources :groups, only: %i[ index new create show destroy ] do
    resource :invite_code, only: :create, controller: "group_invite_codes"
    resources :challenges, only: %i[ new create show ], controller: "group_challenges" do
      resource :closing, only: :create, controller: "group_challenge_closings"
    end
    resources :memberships, only: :destroy, controller: "group_memberships"
  end
  # From a shared link, /join/K7Q2MX, or a code typed on the groups page, /join?code=K7Q2MX
  get "join(/:code)", to: "group_joins#new", as: :join_group
  post "join", to: "group_joins#create", as: :group_joins

  get "play/:topic", to: "games#show", as: :play
  get "learn/:topic/:level", to: "lessons#show", as: :lesson
  post "learn/:topic/:level/done", to: "lesson_completions#create", as: :lesson_completion
  # Where the times tables game used to be, still linked from copies kept on devices
  get "times-tables", to: redirect("/play/times-tables")
  resources :attempts, only: %i[create show]
  get "stats(/:topic)", to: "stats#show", as: :stats
  # Players see their badges as awards (called achievements before)
  resource :awards, only: :show, controller: :badges
  get "badges", to: redirect("/awards")
  get "achievements", to: redirect("/awards")
  get "s/:share_token", to: "shares#show", as: :share

  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
