# Streak freezes keep a streak going through a missed day, which matters for children, who don't control
# their own day. A player holds up to two: bought with stars, or given free when the streak reaches 7 or
# 30 days. They're used up by themselves when the player comes back after missing days, but only if there
# are enough to cover every missed day, as otherwise the streak is lost anyway.
# A frozen day keeps the streak going without adding to it (User::Streakable)
module User::StreakFreezable
  extend ActiveSupport::Concern

  MAX_STREAK_FREEZES = 2
  # Dear enough to be worth saving up for: a good times tables game earns a few hundred
  STREAK_FREEZE_PRICE = 10_000
  FREE_STREAK_FREEZES_AT = [ 7, 30 ]

  class NotAllowed < StandardError; end

  def can_hold_streak_freeze?
    streak_freezes < MAX_STREAK_FREEZES
  end

  def can_buy_streak_freeze?
    can_hold_streak_freeze? && stars >= STREAK_FREEZE_PRICE
  end

  def buy_streak_freeze!
    with_lock do
      raise NotAllowed unless can_buy_streak_freeze?

      update!(streak_freezes: streak_freezes + 1, stars_spent: stars_spent + STREAK_FREEZE_PRICE)
    end
  end

  # A free freeze when the streak, having just grown by some days, passes 7 or 30. True if one was given
  def earn_streak_freeze(grew_by)
    before = current_streak - grew_by
    reached = FREE_STREAK_FREEZES_AT.any? { |days| before < days && current_streak >= days }
    return false unless reached && can_hold_streak_freeze?

    update!(streak_freezes: streak_freezes + 1)
  end

  # Covers the days missed since the streak was last kept, if there are freezes for all of them.
  # Returns how many were used
  def use_streak_freezes!
    return 0 unless streak_kept_on && streak_kept_on < today - 1 && current_streak.positive?

    with_lock do
      missed = missed_days
      next 0 if missed.empty? || missed.size > streak_freezes || current_streak.zero?

      missed.each { |day| frozen_days.create!(day: day) }
      update!(streak_freezes: streak_freezes - missed.size)
      refresh_streak!
      missed.size
    end
  end

  private
    # Whole days gone by without a game since the streak was last kept: not today, which isn't over
    def missed_days
      return [] unless streak_kept_on

      ((streak_kept_on + 1)...today).to_a
    end

    # A game played offline can turn up for a day a freeze covered. That freeze wasn't needed, so it's given back
    def refund_streak_freezes(practised)
      covered = frozen_days.where(day: practised)
      return if covered.none?

      refunds = [ covered.count, MAX_STREAK_FREEZES - streak_freezes ].min
      covered.delete_all
      self.streak_freezes += refunds
    end
end
