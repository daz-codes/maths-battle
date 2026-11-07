# Power-ups in a battle. Each player gets their own, a spinner at the top of their game, at the same answer counts as
# solo (PowerUp::AT), and only they can tap it: what it is is only known then. A player who's fallen far behind gets
# an extra one, one of the strong ones (CATCH_UP), at most every CATCH_UP_EVERY.
#
# Most hit every other player. Freeze, Scramble, Ink blot, Mini text and Mirror only slow them down for a few
# seconds. The Streak breaker ends their streaks and the Bomb takes their scores to nothing, and the Homing shot
# breaks only the leader's streak. Those count in the scores, so each game takes them at the point its player had
# answered up to when it was claimed (powers_in).
#
# Some help the one who claims them instead: Coins add 100 to their score, and a Superstar counts their next
# answers as right and keeps them from being hit for STAR_SECONDS. A Shield (stored as "horn") is held until the next
# attack that would hit them, which it blocks. Who was saved, by a Shield or a Superstar, is decided here when an attack is claimed.
#
# Curveballs (everyone else's next questions from the hardest tier) and Rockets (the claimer's next ones from the
# easiest) change which questions a game asks, so each game says where they landed, and that's checked against the
# drop, at about the time it was claimed, before its answers are (shifts_for). A Shot freezes only the player just
# ahead (or just behind, for the leader), and a Rocket claimed by the leader is Coins instead: it's for catching up.
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
  # Far behind is under this much of the leader's score, once the leader has CATCH_UP_LEADER_FROM
  CATCH_UP_BEHIND = 0.5
  CATCH_UP_LEADER_FROM = 300
  CATCH_UP_EVERY = 15.seconds
  CATCH_UP = %w[ rocket homing curveball star ]
  # Which tier a shift moves questions to (nil for the hardest), and for how many questions
  SHIFTS = { "curveball" => [ nil, 3 ], "rocket" => [ 0, 5 ] }
  # How many answers out a game's own account of where a shift landed can be from where its times put it
  SHIFT_SLACK = 3
  # What hits the others' scores, and what helps the claimer's own
  SCORING = %w[ reset bomb homing ]
  OWN_SCORING = %w[ coins star ]

  included do
    has_many :drops, dependent: :destroy
  end

  # A player's answers so far, as they say while playing: the power-ups it brings them, one for each of
  # PowerUp::AT they pass
  def answered(player, count, random: Random.new)
    count = count.clamp(player.answered, Attempt::Recordable::MAX_ANSWERS)
    passed = PowerUp::AT.count { |at| at > player.answered && at <= count }
    player.update_columns(answered: count) if count != player.answered
    return [] unless running?

    Array.new(passed) { drops.create!(owner: player.user, power_up: PowerUp::DROPPED.sample(random: random)) }
  end

  # An extra power-up for each player who's fallen far behind, if they haven't had one lately
  def catch_up(random: Random.new, now: Time.current)
    return [] unless running?

    leader = players.maximum(:live_score).to_i
    return [] if leader < CATCH_UP_LEADER_FROM

    players.where(live_score: ...(leader * CATCH_UP_BEHIND)).filter_map do |player|
      next if player.caught_up_at&.after?(now - CATCH_UP_EVERY)

      player.update_columns(caught_up_at: now)
      drops.create!(owner: player.user, power_up: CATCH_UP.sample(random: random))
    end
  end

  # Only its owner can claim it, once. Nil when it isn't theirs, it's been claimed, or the game's over
  def claim(drop_id, player, random: Random.new)
    drop = drops.find_by(id: drop_id, owner_id: player.user_id)
    return unless drop && running?

    claimed = LiveGame::Drop.where(id: drop.id, claimed_by_id: nil).update_all(claimed_by_id: player.user_id, claimed_at: Time.current)
    return unless claimed == 1

    transaction do
      player.reload
      drop.update!(power_up: "bomb") if bomb_for?(player, random)
      drop.update!(power_up: "coins") if drop.power_up == "rocket" && leader_besides(player).then { |other| other.nil? || player.live_score >= other.live_score }
      case drop.power_up
      when "horn" then player.increment!(:horns)
      when "star" then player.update!(star_until: STAR_SECONDS.seconds.from_now)
      when "homing" then drop.update!(target: leader_besides(player)&.user)
      when "shot" then drop.update!(target: next_to(player)&.user)
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

  # Where this player's game says its Curveballs and Rockets landed, as { answer index => [ tier, questions ] }, each
  # checked: a Curveball someone else claimed that hit them, or a Rocket they claimed, landing about when its times
  # say. A game that missed hearing of one (a dropped connection) just doesn't have it
  def shifts_for(user, reported, answers, tiers)
    finished = elapsed_after_each(answers.map { |answer| { "ms" => Integer(answer.to_h.stringify_keys["ms"], exception: false).to_i, "correct" => true } })
    used = []
    reported.each_with_object({}) do |shift, shifts|
      shift = shift.respond_to?(:to_h) ? shift.to_h.stringify_keys : {}
      drop, at = drops.find_by(id: shift["drop"]), Integer(shift["at"], exception: false)
      raise Attempt::Invalid, "Bad power-up" unless drop && at && SHIFTS.key?(drop.power_up) && used.exclude?(drop.id) && shifted?(drop, user)

      landed = finished.count { |ms| ms <= (drop.claimed_at - starts_at) * 1000 } + 1
      raise Attempt::Invalid, "Bad power-up" unless at.between?(landed - SHIFT_SLACK, landed + SHIFT_SLACK) && at.between?(0, answers.size)

      used << drop.id
      tier, questions = SHIFTS.fetch(drop.power_up)
      shifts[at] = [ tier || tiers - 1, questions ]
    end
  end

  private
    def shifted?(drop, user)
      if drop.power_up == "rocket" then drop.claimed_by_id == user.id
      else drop.claimed? && drop.claimed_by_id != user.id && drop.hits?(user)
      end
    end

    def scores_for?(drop, user)
      if drop.claimed_by_id == user.id
        OWN_SCORING.include?(drop.power_up)
      else
        SCORING.include?(drop.power_up) && drop.hits?(user)
      end
    end

    # Everyone it would hit who's running a Superstar, or holding a Shield, which it uses up
    def block(drop)
      saved = drop.victims.select do |victim|
        if victim.star_until&.future? then true
        elsif victim.horns.positive? then victim.decrement!(:horns)
        end
      end
      drop.update!(blocked_ids: saved.map(&:user_id))
    end

    # By score: players are listed in the order they joined, so these reorder
    def leader_besides(player)
      players.where.not(id: player.id).reorder(live_score: :desc, id: :asc).first
    end

    # The player just ahead, or for the leader, the one just behind
    def next_to(player)
      others = players.where.not(id: player.id)
      others.where(live_score: (player.live_score + 1)..).reorder(:live_score, :id).first || others.reorder(live_score: :desc, id: :asc).first
    end

    def elapsed_after_each(results)
      total = 0
      results.map { |result| total += result["ms"] + (result["correct"] || result["skip"] ? 0 : WRONG_PAUSE_MS) }
    end
end
