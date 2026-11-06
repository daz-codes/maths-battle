# Power-ups in a battle. Whenever any player answers another PowerUp::EVERY, one drops for everyone, a spinner at the
# top of their game, and the first to tap it claims it: what it is is only known then. It hits every other player.
# Freeze and Scramble only slow them down for a few seconds, and the Streak breaker ends their streak, so it counts
# in their score: their game takes it at the point they'd answered up to when it was claimed (hits_on)
module LiveGame::Droppable
  extend ActiveSupport::Concern

  # The question a player was on when they were hit is worked out from their answers' times, which leave out the
  # moment a wrong answer shows in red (WRONG_PAUSE in test_controller.js)
  WRONG_PAUSE_MS = 400

  included do
    has_many :drops, dependent: :destroy
  end

  # A player's answers so far, as they say while playing. A new power-up drops each time they pass another ten
  def answered(player, count, random: Random.new)
    count = count.clamp(player.answered, Attempt::Recordable::MAX_ANSWERS)
    return if count == player.answered

    passed = count / PowerUp::EVERY > player.answered / PowerUp::EVERY
    player.update_columns(answered: count)
    drops.create!(power_up: PowerUp::BATTLE.keys.sample(random: random)) if passed && running?
  end

  # The first to ask gets it. Nil when someone else got there first, or the game's over
  def claim(drop_id, player)
    drop = drops.find_by(id: drop_id)
    return unless drop && running?

    claimed = LiveGame::Drop.where(id: drop.id, claimed_by_id: nil).update_all(claimed_by_id: player.user_id, claimed_at: Time.current)
    drop.reload if claimed == 1
  end

  # The Streak breakers that hit this player, each at the number of answers they'd given by the time it was
  # claimed, going by how long their answers took from the start
  def hits_on(user, results)
    finished = elapsed_after_each(results)
    drops.where(power_up: "reset").where.not(claimed_by_id: [ nil, user.id ]).order(:claimed_at).map do |drop|
      at = finished.count { |ms| ms <= (drop.claimed_at - starts_at) * 1000 }
      { "kind" => "reset", "at" => at, "from" => drop.claimed_by_id }
    end
  end

  private
    def elapsed_after_each(results)
      total = 0
      results.map { |result| total += result["ms"] + (result["correct"] ? 0 : WRONG_PAUSE_MS) }
    end
end
