# Gems, kept but not shown for now: what a game earns to spend on streak freezes (User::StreakFreezable), its score
# with bonuses on top. Players see the score (Scorable) instead
module Attempt::Gemmable
  extend ActiveSupport::Concern

  BONUSES = { perfect: 50, high_score: 50, level_up: 100, review: 50 }

  # The bonuses this game earned, like { perfect: 50 }
  def gem_bonuses
    earned = review? ? { review: answered.positive? } : { perfect: perfect_game?, high_score: new_high_score, level_up: levelled_up }
    earned.select { |_, bonus| bonus }.to_h { |bonus, _| [ bonus, BONUSES[bonus] ] }
  end

  def count_gems
    points + gem_bonuses.values.sum
  end

  private
    def award_gems
      update_column(:gems, count_gems)
    end
end
