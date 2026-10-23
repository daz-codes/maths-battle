# Someone in a live game's lobby, and once they've played, their game: the first one saved in time
class LiveGame::Player < ApplicationRecord
  belongs_to :live_game
  belongs_to :user
  belongs_to :attempt, optional: true

  validates :user_id, uniqueness: { scope: :live_game_id }

  def played? = attempt_id.present?
end
