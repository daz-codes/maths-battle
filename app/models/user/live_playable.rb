# The live games a player hosts (LiveGame). They play in them through LiveGame::Player, like anyone who joins
module User::LivePlayable
  extend ActiveSupport::Concern

  included do
    has_many :hosted_live_games, class_name: "LiveGame", foreign_key: :host_id, dependent: :destroy, inverse_of: :host
    has_many :live_game_players, class_name: "LiveGame::Player", dependent: :destroy
  end
end
