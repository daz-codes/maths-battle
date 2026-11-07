# Power-ups in a battle. Whenever any player answers another PowerUp::EVERY, one drops for everyone, a spinner at the
# top of their game, and the first to tap it claims it: what it is is only known then. It hits every other player.
# Freeze, Scramble, Ink blot and Mini text only slow them down for a few seconds. The Streak breaker ends their
# streak and the Bomb takes their score to nothing, so those count in their scores: their games take them at the
# point they'd answered up to when it was claimed (hits_on).
#
# A drop claimed by someone far behind can turn out to be the Bomb: only when they've under BOMB_BEHIND of the
# leader's score, the leader has a score worth bombing, by chance, and once a battle
module LiveGame::Droppable
  extend ActiveSupport::Concern

  # The question a player was on when they were hit is worked out from their answers' times, which leave out the
  # moment a wrong answer shows in red (WRONG_PAUSE in test_controller.js)
  WRONG_PAUSE_MS = 400
  BOMB_BEHIND = 0.5
  BOMB_LEADER_FROM = 300
  BOMB_CHANCE = 0.35
  # What hits a player's score, rather than just their screen
  SCORING = %w[ reset bomb ]

  included do
    has_many :drops, dependent: :destroy
  end

  # A player's answers so far, as they say while playing. A new power-up drops each time they pass another ten
  def answered(player, count, random: Random.new)
    count = count.clamp(player.answered, Attempt::Recordable::MAX_ANSWERS)
    return if count == player.answered

    passed = count / PowerUp::EVERY > player.answered / PowerUp::EVERY
    player.update_columns(answered: count)
    drops.create!(power_up: PowerUp::DROPPED.sample(random: random)) if passed && running?
  end

  # The first to ask gets it. Nil when someone else got there first, or the game's over
  def claim(drop_id, player, random: Random.new)
    drop = drops.find_by(id: drop_id)
    return unless drop && running?

    claimed = LiveGame::Drop.where(id: drop.id, claimed_by_id: nil).update_all(claimed_by_id: player.user_id, claimed_at: Time.current)
    return unless claimed == 1

    drop.update!(power_up: "bomb") if bomb_for?(player, random)
    drop.reload
  end

  # Far behind a leader worth bombing, and no Bomb yet this battle
  def bomb_for?(player, random = Random.new)
    leader = players.where.not(id: player.id).maximum(:live_score).to_i
    leader >= BOMB_LEADER_FROM && player.reload.live_score < leader * BOMB_BEHIND &&
      !drops.exists?(power_up: "bomb") && random.rand < BOMB_CHANCE
  end

  # The Streak breakers and Bombs that hit this player, each at the number of answers they'd given by the time it
  # was claimed, going by how long their answers took from the start
  def hits_on(user, results)
    finished = elapsed_after_each(results)
    drops.where(power_up: SCORING).where.not(claimed_by_id: [ nil, user.id ]).order(:claimed_at).map do |drop|
      at = finished.count { |ms| ms <= (drop.claimed_at - starts_at) * 1000 }
      { "kind" => drop.power_up, "at" => at, "from" => drop.claimed_by_id }
    end
  end

  private
    def elapsed_after_each(results)
      total = 0
      results.map { |result| total += result["ms"] + (result["correct"] ? 0 : WRONG_PAUSE_MS) }
    end
end
