# A streak counts the days in a row a player has practised, in their own time zone.
# Games played offline can reach the server days later and out of order, so the streak is worked out
# again from the days that have games, rather than counted up as games arrive.
# The time zone comes from the player's device with each game, so the day ends at their own midnight
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

  def refresh_streak!
    days = practised_days
    runs = runs_of_days(days)
    update!(current_streak: runs.last.to_i, longest_streak: [ longest_streak, runs.max.to_i ].max, last_practised_on: days.last)
  end

  # The streak as it stands today: it's lost once a whole day has been missed
  def streak
    practised_since?(today - 1) ? current_streak : 0
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

    def practised_days
      attempts.counted.distinct.order(:played_on).pluck(:played_on)
    end

    # [14th, 15th, 16th, 18th] → [3, 1]: the lengths of each stretch of days in a row
    def runs_of_days(days)
      days.slice_when { |day, next_day| next_day != day + 1 }.map(&:size)
    end
end
