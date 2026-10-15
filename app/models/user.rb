class User < ApplicationRecord
  THEMES = %w[ system light dark ]

  # Guests play without signing up, so they have no username or password until they register
  has_secure_password validations: false
  has_many :sessions, dependent: :destroy
  has_many :attempts, dependent: :destroy
  has_many :fact_stats, dependent: :destroy

  normalizes :username, with: ->(u) { u.strip.downcase.presence }
  normalizes :name, with: ->(n) { n.squish.presence }

  with_options if: :registering? do
    validates :username, presence: true, uniqueness: true,
      format: { with: /\A[a-z0-9_]+\z/, message: "can only use letters, numbers and _", allow_blank: true },
      length: { in: 3..20, allow_blank: true }
    validate { errors.add(:password, :blank) if password_digest.blank? }
  end
  validates :name, presence: true, on: :registration
  validates :password, length: { in: 4..72 }, allow_nil: true
  validates :name, length: { maximum: 30 }
  validates :theme, inclusion: { in: THEMES }
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }

  def self.create_guest!
    create!
  end

  def guest?
    username.nil?
  end

  # Turns a guest into a registered user, keeping their streak and history
  def register(attributes)
    assign_attributes(attributes)
    save(context: :registration)
  end

  def display_name
    name || username
  end

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
    def registering?
      username.present? || validation_context == :registration
    end

    def practised_since?(date)
      last_practised_on.present? && last_practised_on >= date
    end
end
