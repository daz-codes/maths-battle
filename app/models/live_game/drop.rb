# A power-up dropped into a battle, waiting for someone to tap it (LiveGame::Droppable). A Homing shot has the one
# it went for; an attack has whoever a Horn or a Superstar saved from it
class LiveGame::Drop < ApplicationRecord
  belongs_to :live_game
  belongs_to :claimed_by, class_name: "User", optional: true
  belongs_to :target, class_name: "User", optional: true

  validates :power_up, inclusion: { in: PowerUp::BATTLE.keys }

  def claimed? = claimed_by_id.present?

  # The players it's aimed at: the Homing shot's one, or everyone but the claimer
  def victims
    others = live_game.players.where.not(user_id: claimed_by_id)
    power_up == "homing" ? others.where(user_id: target_id) : others
  end

  def hits?(user)
    blocked_ids.exclude?(user.id) && (power_up != "homing" || target_id == user.id)
  end
end
