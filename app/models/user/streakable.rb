# A streak counts the days in a row a player has practised, in their own time zone
module User::Streakable
  extend ActiveSupport::Concern

  included do
    validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }
  end

  def today
    ActiveSupport::TimeZone[time_zone].today
  end

  # Counts one day of practice. Practising again on the same day changes nothing
  def record_practice!(date = today)
    return if practised_since?(date)

    self.current_streak = continues_streak?(date) ? current_streak + 1 : 1
    self.longest_streak = [ longest_streak, current_streak ].max
    self.last_practised_on = date
    save!
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

    def continues_streak?(date)
      last_practised_on == date - 1
    end
end
