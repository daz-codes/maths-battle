# The awards a player has collected, and their records: the longest run of right answers, the most right and the
# highest score, each in one game
module User::Badgeable
  extend ActiveSupport::Concern

  included do
    has_many :badges, dependent: :destroy
  end

  def badges_by_kind
    @badges_by_kind ||= badges.index_by(&:kind)
  end

  def longest_streak
    attempts.maximum(:best_streak) || 0
  end

  def most_correct
    attempts.maximum(:correct) || 0
  end
end
