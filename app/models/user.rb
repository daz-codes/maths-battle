class User < ApplicationRecord
  include Abandonable, Avatarable, Badgeable, Leaguable, LivePlayable, Registerable, Themeable

  has_many :sessions, dependent: :destroy
  has_many :attempts, dependent: :destroy
  has_many :match_requests, dependent: :destroy

  # Shown in the leagues: everyone but a guest who hasn't given a name
  scope :named, -> { where.not(name: nil).or(where.not(username: nil)) }

  def named?
    display_name.present?
  end

  def best_score
    attempts.maximum(:score) || 0
  end

  def best_today
    attempts.solo.on(League.today).maximum(:score)
  end
end
