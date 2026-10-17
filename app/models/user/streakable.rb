# A streak counts the days in a row a player has practised, in their own time zone.
# Games played offline can reach the server days later and out of order, so the streak is worked out
# again from the days that have games, rather than counted up as games arrive.
# The time zone comes from the player's device with each game, so the day ends at their own midnight.
# A day covered by a streak freeze (User::StreakFreezable) keeps the streak going, but doesn't add to it
module User::Streakable
  extend ActiveSupport::Concern

  included do
    validate :time_zone_known
  end

  # A zone as the browser names it, like "America/New_York". Anything unknown keeps the one there is
  def update_time_zone(zone)
    update(time_zone: zone) if zone.is_a?(String) && zone != time_zone && ActiveSupport::TimeZone[zone]
  end

  def today
    ActiveSupport::TimeZone[time_zone].today
  end

  # Returns how many days the streak grew by, so a freeze can be earned on the way
  def refresh_streak!
    practised = practised_days
    refund_streak_freezes(practised)
    runs = runs_of_days(practised, kept_days(practised))
    before = current_streak
    update!(current_streak: runs.last.to_i, longest_streak: [ longest_streak, runs.max.to_i ].max,
      last_practised_on: practised.last, streak_kept_on: kept_days(practised).last)
    current_streak - before
  end

  # The streak as it stands today: it's lost once a whole day has been missed, unless a freeze covered it
  def streak
    kept_since?(today - 1) ? current_streak : 0
  end

  def practised_today?
    practised_since?(today)
  end

  def streak_at_risk?
    streak.positive? && !practised_today?
  end

  private
    def time_zone_known
      errors.add(:time_zone, :inclusion) unless ActiveSupport::TimeZone[time_zone.to_s]
    end

    def practised_since?(date)
      last_practised_on.present? && last_practised_on >= date
    end

    def kept_since?(date)
      streak_kept_on.present? && streak_kept_on >= date
    end

    def practised_days
      attempts.counted.distinct.order(:played_on).pluck(:played_on)
    end

    # Practised days and frozen ones, in order
    def kept_days(practised)
      (practised + frozen_days.pluck(:day)).uniq.sort
    end

    # [14th, 15th, 16th (frozen), 17th, 19th] → [3, 1]: for each stretch of days in a row, how many were practised
    def runs_of_days(practised, kept)
      practised = practised.to_set
      kept.slice_when { |day, next_day| next_day != day + 1 }.map { |run| run.count { |day| practised.include?(day) } }
    end
end
