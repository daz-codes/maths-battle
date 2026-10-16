# A streak counts the days in a row a player has practised, in their own time zone.
# Games played offline can reach the server days later and out of order, so the streak is worked out
# again from the days that have games, rather than counted up as games arrive
module User::Streakable
  extend ActiveSupport::Concern

  included do
    validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }
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
