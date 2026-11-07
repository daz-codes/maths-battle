# The awards a game earns. Each is earned once, by the first game that meets its rule (Badge::Catalogued). A
# battle's game is awarded once it's joined its battle, so the power-ups claimed in it count
module Attempt::Badgeable
  extend ActiveSupport::Concern

  PERFECT_ANSWERS = 10

  included do
    has_many :badges, dependent: :nullify
  end

  def award_badges
    earned = user.badges.pluck(:kind)
    Badge.catalogue.each do |kind|
      next if kind.check.nil? || earned.include?(kind.key)

      Badge.award(user, kind.key, attempt: self, at: played_at) if public_send(*kind.check)
    end
  end

  # The rules

  def finished?
    answered.positive?
  end

  def battle_finished?
    battle? && finished?
  end

  def streak_at_least?(streak)
    best_streak >= streak
  end

  def right_at_least?(right)
    correct >= right
  end

  def scored_at_least?(score)
    self.score >= score
  end

  def claimed?(power_up)
    claimed_power_ups.include?(power_up)
  end

  def claimed_power_up?
    claimed_power_ups.any?
  end

  def perfect_game?
    answered >= PERFECT_ANSWERS && correct == answered
  end

  def reached_the_top?
    top_tier >= Ladder::TIERS.size
  end

  def in_the_top_ten?
    world = League.world(played_on)
    user.named? && world.size >= Badge::TOP_TEN_FROM && world.entry_for(user)&.rank.to_i.between?(1, 10)
  end

  private
    # Solo, what its spinners gave; in a battle, the drops this player tapped first
    def claimed_power_ups
      @claimed_power_ups ||=
        if battle? then live_game&.drops&.where(claimed_by: user)&.pluck(:power_up) || []
        else powers.map { |power| power["kind"] }
        end
    end
end
