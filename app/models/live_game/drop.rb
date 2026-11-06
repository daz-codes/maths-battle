# A power-up dropped into a battle, waiting for someone to tap it (LiveGame::Droppable)
class LiveGame::Drop < ApplicationRecord
  belongs_to :live_game
  belongs_to :claimed_by, class_name: "User", optional: true

  validates :power_up, inclusion: { in: PowerUp::BATTLE.keys }

  def claimed? = claimed_by_id.present?
end
