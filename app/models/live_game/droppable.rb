# Power-ups in a battle. Whenever any player answers another PowerUp::EVERY, one drops for everyone, a spinner at the
# top of their game, and the first to tap it claims it: what it is is only known then.
#
# Most hit every other player. Freeze, Scramble, Ink blot, Mini text and Mirror only slow them down for a few
# seconds. The Streak breaker ends their streaks and the Bomb takes their scores to nothing, and the Homing shot
# breaks only the leader's streak. Those count in the scores, so each game takes them at the point its player had
# answered up to when it was claimed (powers_in).
#
# Some help the one who claims them instead: Coins add 100 to their score, and a Superstar counts their next
# answers as right and keeps them from being hit for STAR_SECONDS. A Horn is held until the next attack that would
# hit them, which it blocks. Who was saved, by a Horn or a Superstar, is decided here when an attack is claimed.
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
  STAR_SECONDS = 8
  # What hits the others' scores, and what helps the claimer's own
  SCORING = %w[ reset bomb homing ]
  OWN_SCORING = %w[ coins star ]

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

    transaction do
      drop.update!(power_up: "bomb") if bomb_for?(player, random)
      case drop.power_up
      when "horn" then player.increment!(:horns)
      when "star" then player.update!(star_until: STAR_SECONDS.seconds.from_now)
      when "homing" then drop.update!(target: leader_besides(player)&.user)
      end
      block(drop) if PowerUp.attack?(drop.power_up)
    end
    drop.reload
  end

  # Far behind a leader worth bombing, and no Bomb yet this battle
  def bomb_for?(player, random = Random.new)
    leader = players.where.not(id: player.id).maximum(:live_score).to_i
    leader >= BOMB_LEADER_FROM && player.reload.live_score < leader * BOMB_BEHIND &&
      !drops.exists?(power_up: "bomb") && random.rand < BOMB_CHANCE
  end

  # What changed this player's score from the battle's power-ups: what hit them, and the Coins and Superstars they
  # claimed, each at the number of answers they'd given by the time it was claimed, going by how long their answers
  # took from the start
  def powers_in(user, results)
    finished = elapsed_after_each(results)
    drops.where.not(claimed_by_id: nil).order(:claimed_at).filter_map do |drop|
      next unless scores_for?(drop, user)

      at = finished.count { |ms| ms <= (drop.claimed_at - starts_at) * 1000 }
      { "kind" => drop.power_up, "at" => at, "from" => drop.claimed_by_id }
    end
  end

  private
    def scores_for?(drop, user)
      if drop.claimed_by_id == user.id
        OWN_SCORING.include?(drop.power_up)
      else
        SCORING.include?(drop.power_up) && drop.hits?(user)
      end
    end

    # Everyone it would hit who's running a Superstar, or holding a Horn, which it uses up
    def block(drop)
      saved = drop.victims.select do |victim|
        if victim.star_until&.future? then true
        elsif victim.horns.positive? then victim.decrement!(:horns)
        end
      end
      drop.update!(blocked_ids: saved.map(&:user_id))
    end

    def leader_besides(player)
      players.where.not(id: player.id).order(live_score: :desc, id: :asc).first
    end

    def elapsed_after_each(results)
      total = 0
      results.map { |result| total += result["ms"] + (result["correct"] ? 0 : WRONG_PAUSE_MS) }
    end
end
