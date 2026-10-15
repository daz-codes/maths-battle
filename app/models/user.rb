class User < ApplicationRecord
  include Avatarable, Practisable, Registerable, Scorable, Streakable, Themeable, Trackable

  has_many :sessions, dependent: :destroy
  has_many :attempts, dependent: :destroy
  has_many :fact_stats, dependent: :destroy

  # The player's record for each times tables fact, keyed like "7x8"
  def times_tables_stats
    @times_tables_stats ||= fact_stats.where(topic: TimesTables::TOPIC).index_by(&:fact)
  end
end
