# Stars: what a game earns, as it's played and at the end. Every right answer earns some, more for a quick
# one; the game can earn a bonus on top. Worked out here from the checked answers, so the +10s that float
# up during the game are just for show. A review has no clock, so its answers earn nothing: finishing it does
module Attempt::Starrable
  extend ActiveSupport::Concern

  RIGHT = 10
  QUICK = 20
  LIGHTNING = 30
  BONUSES = { perfect: 50, high_score: 50, level_up: 100, review: 50 }
  BONUS_NAMES = { perfect: "Perfect game", high_score: "New high score", level_up: "Level up", review: "Mistakes reviewed" }

  class_methods do
    # Stars for one answer: none if wrong, then more the quicker it was. Each topic says what's quick, as an
    # equation takes longer than a times table
    def stars_for(result, topic)
      return 0 unless result["correct"]

      times = topic.star_times
      if result["ms"] < times[:lightning] then LIGHTNING
      elsif result["ms"] < times[:quick] then QUICK
      else RIGHT
      end
    end
  end

  def answer_stars
    return 0 if review?

    results.sum { |result| self.class.stars_for(result, topic_module) }
  end

  # The bonuses this game earned, like { perfect: 50 }
  def star_bonuses
    earned = review? ? { review: answered.positive? } : { perfect: perfect_game?, high_score: new_high_score, level_up: levelled_up }
    earned.select { |_, bonus| bonus }.to_h { |bonus, _| [ bonus, BONUSES[bonus] ] }
  end

  def count_stars
    answer_stars + star_bonuses.values.sum
  end

  private
    def award_stars
      update_column(:stars, count_stars)
    end
end
