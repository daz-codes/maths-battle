class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :attempts, dependent: :destroy
  has_many :fact_stats, dependent: :destroy

  normalizes :username, with: ->(u) { u.strip.downcase }

  validates :username, presence: true, uniqueness: true,
    format: { with: /\A[a-z0-9_]+\z/, message: "can only use letters, numbers and _" },
    length: { in: 3..20 }
  validates :password, length: { minimum: 4 }, allow_nil: true
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }

  def today
    ActiveSupport::TimeZone[time_zone].today
  end

  # Counts one day of practice. Practising again on the same day changes nothing
  def record_practice!(date = today)
    return if last_practised_on && last_practised_on >= date

    self.current_streak = last_practised_on == date - 1 ? current_streak + 1 : 1
    self.longest_streak = [ longest_streak, current_streak ].max
    self.last_practised_on = date
    save!
  end

  # Returns true when the score beats the previous best
  def record_score!(score)
    return false unless score > high_score

    update!(high_score: score)
    true
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
end
