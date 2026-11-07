Rails.application.routes.draw do
  root "home#show"

  resource :session, only: %i[new create destroy]
  resource :registration, only: %i[new create]
  resource :profile, only: %i[edit update]
  resource :avatar, only: :show

  resource :awards, only: :show
  get "how-it-works", to: "how_it_works#show", as: :how_it_works

  # A solo game, or a battle's (?live=K7Q2M)
  get "play", to: "games#show", as: :play
  resources :attempts, only: %i[create show]

  # Multiplayer: finding a match with anyone looking, or hosting a battle for friends to join with its code
  resource :multiplayer, only: :show, controller: "multiplayer"
  resource :match, only: %i[show create]
  # Battles, at /live/K7Q2M: its lobby (and podium), joining it, the host starting it, and playing again. A code
  # typed in is /live?code=K7Q2M
  resources :live_games, only: %i[ index create show ], path: "live", param: :code do
    resource :player, only: :create, controller: "live_game_players"
    resource :start, only: :create, controller: "live_game_starts"
    resource :rematch, only: :create, controller: "live_game_rematches"
  end

  # The world league and a player's own leagues
  resources :leagues, only: %i[ index new create show destroy ] do
    resource :invite_code, only: :create, controller: "league_invite_codes"
    resources :memberships, only: :destroy, controller: "league_memberships"
  end
  # From a shared link, /join/K7Q2MX, or a code typed on the leagues page, /join?code=K7Q2MX
  get "join(/:code)", to: "league_joins#new", as: :join_league
  post "join", to: "league_joins#create", as: :league_joins

  get "up" => "rails/health#show", as: :rails_health_check
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
