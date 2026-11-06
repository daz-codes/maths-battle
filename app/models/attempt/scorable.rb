# A game's score, from streaks: the first right answer scores 10, the next in a row 20, then 30, 40 and on, and a
# wrong answer ends the streak, so the next right one is back to 10. Power-ups change that as they're claimed:
# Double points doubles the next five right answers, a Streak shield saves the streak from the next wrong one, and in
# a battle a Streak breaker from someone else ends it. Worked out here from the checked answers and power-ups, so
# what floats up during the game is just for show
module Attempt::Scorable
  extend ActiveSupport::Concern

  STEP = 10

  # The score, the longest streak, and the score after each answer
  Tally = Data.define(:score, :best_streak, :running)

  class_methods do
    # powers: what was claimed (or hit this player), each at the number of answers given by then
    def tally(results, powers)
      by_answer = powers.group_by { |power| power["at"] }
      score, streak, best, doubles, shields, running = 0, 0, 0, 0, 0, []
      results.each_with_index do |result, index|
        by_answer.fetch(index, []).each do |power|
          case power["kind"]
          when "double" then doubles += PowerUp::SOLO.dig("double", :answers)
          when "shield" then shields += 1
          when "reset" then streak = 0
          end
        end
        if result["correct"]
          streak += 1
          points = STEP * streak
          if doubles.positive?
            points *= 2
            doubles -= 1
          end
          score += points
        elsif shields.positive?
          shields -= 1
        else
          streak = 0
        end
        best = [ best, streak ].max
        running << score
      end
      Tally.new(score:, best_streak: best, running:)
    end
  end

  def tally
    @tally ||= self.class.tally(results, powers)
  end
end
