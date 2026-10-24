# Gems: what a game earns, as it's played and at the end. Every right answer earns some, and a quick one earns
# more for its speed on top; a wrong answer loses a few. Right answers in a row build a combo that multiplies what
# each earns, and a wrong one ends it. The game can earn a bonus on top. Worked out here from the checked answers,
# so what floats up during the game is just for show, and a game never comes to less than nothing. (Stars rate a
# level instead: Rateable.) A review has no clock, so its answers earn nothing: finishing it does
module Attempt::Gemmable
  extend ActiveSupport::Concern

  RIGHT = 10
  SPEED = { quick: 10, lightning: 20 }
  WRONG = -5
  # Right answers in a row: ×2 from the 5th, ×3 from the 10th, ×4 from the 20th
  COMBOS = { 20 => 4, 10 => 3, 5 => 2 }
  BONUSES = { perfect: 50, high_score: 50, level_up: 100, review: 50 }
  BONUS_NAMES = { perfect: "Perfect game", high_score: "New high score", level_up: "Level up", review: "Mistakes reviewed" }
  TALLY_NAMES = { right: "Right answers", speed: "Speed", combo: "Combos", wrong: "Wrong answers" }

  class_methods do
    # :lightning, :quick or nil. Each topic says what's quick, as an equation takes longer than a times table
    def speed_of(result, topic)
      times = topic.gem_times
      if result["ms"] < times[:lightning] then :lightning
      elsif result["ms"] < times[:quick] then :quick
      end
    end

    def multiplier_for(in_a_row)
      COMBOS.find { |from, _| in_a_row >= from }&.last || 1
    end

    # The rules, for the game to show the same as it goes
    def gem_rules(topic)
      { right: RIGHT, speed: SPEED, wrong: WRONG, combos: COMBOS.sort.to_h, times: topic.gem_times }
    end
  end

  # Where the answers' gems came from, like { right: 200, speed: 150, combo: 180, wrong: -10 }, and the longest run
  def gem_tally
    @gem_tally ||= begin
      tally, in_a_row, longest = { right: 0, speed: 0, combo: 0, wrong: 0 }, 0, 0
      results.each do |result|
        if result["correct"]
          in_a_row += 1
          longest = [ longest, in_a_row ].max
          speed = SPEED.fetch(self.class.speed_of(result, topic_module), 0)
          tally[:right] += RIGHT
          tally[:speed] += speed
          tally[:combo] += (RIGHT + speed) * (self.class.multiplier_for(in_a_row) - 1)
        else
          in_a_row = 0
          tally[:wrong] += WRONG
        end
      end
      tally.merge(longest_run: longest)
    end
  end

  def answer_gems
    return 0 if review?

    [ gem_tally.except(:longest_run).values.sum, 0 ].max
  end

  # The bonuses this game earned, like { perfect: 50 }
  def gem_bonuses
    earned = review? ? { review: answered.positive? } : { perfect: perfect_game?, high_score: new_high_score, level_up: levelled_up }
    earned.select { |_, bonus| bonus }.to_h { |bonus, _| [ bonus, BONUSES[bonus] ] }
  end

  def count_gems
    answer_gems + gem_bonuses.values.sum
  end

  private
    def award_gems
      update_column(:gems, count_gems)
    end
end
