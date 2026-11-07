# One minute's game: solo, or in a battle against others (LiveGame). Its questions get harder or easier as the
# player does (Ladder), its score comes from streaks and power-ups (Scorable), and its best each day is the player's place in
# the leagues (League)
class Attempt < ApplicationRecord
  include Badgeable, Recordable, Scorable

  MODES = %w[ solo battle ]

  belongs_to :user

  validates :mode, inclusion: { in: MODES }

  scope :on, ->(day) { where(played_on: day) }
  scope :solo, -> { where(mode: "solo") }

  def solo? = mode == "solo"
  def battle? = mode == "battle"

  # The battle it was played in
  def live_game
    LiveGame::Player.find_by(attempt_id: id)&.live_game
  end

  def wrong
    answered - correct
  end
end
