class User < ApplicationRecord
  include Avatarable, Levelable, Practisable, Registerable, Scorable, Streakable, Themeable, Trackable

  has_many :sessions, dependent: :destroy
  has_many :attempts, dependent: :destroy
  has_many :fact_stats, dependent: :destroy

  # The player's record for each fact in a topic's level, keyed like "7x8" or "ax+b=c"
  def stats_for(topic, level)
    (@stats_for ||= {})[[ topic, level ]] ||= fact_stats.where(topic: topic::TOPIC, level: level).index_by(&:fact)
  end
end
