# A game's score, from streaks: the first right answer scores 10, the next in a row 20, then 30, 40 and on, and a
# wrong answer ends the streak, so the next right one is back to 10. Power-ups change that as they're claimed:
# a Bonus +10, Bonus +20 or Boost adds 10, 20 or 30 to each of the next five right answers (each running at once
# adds its own), a Streak shield saves the streak from the next wrong one, and in a battle someone else's Streak
# breaker or Homing shot ends it, and their Bomb takes the score back to nothing as well. Coins add 100 there and
# then, and a Superstar counts the next five answers as right, whatever was typed. They still count as wrong for
# how hard the questions get (Ladder), and in how many were right (Recordable's correct). Worked out here from the checked answers and power-ups, so
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
      score, streak, best, doubles, triples, boosts, shields, stars, running = 0, 0, 0, 0, 0, 0, 0, 0, []
      results.each_with_index do |result, index|
        by_answer.fetch(index, []).each do |power|
          case power["kind"]
          when "double" then doubles += PowerUp::SOLO.dig("double", :answers)
          when "triple" then triples += PowerUp::SOLO.dig("triple", :answers)
          when "boost" then boosts += PowerUp::SOLO.dig("boost", :answers)
          when "shield" then shields += 1
          when "star" then stars += PowerUp::SOLO.dig("star", :answers)
          when "coins" then score += PowerUp::SOLO.dig("coins", :points)
          when "reset", "homing" then streak = 0
          when "bomb" then score, streak = 0, 0
          end
        end
        if result["skip"]
          running << score
          next
        end

        starred = stars.positive?
        stars -= 1 if starred
        if result["correct"] || starred
          streak += 1
          points = STEP * streak
          if doubles.positive?
            points += PowerUp::SOLO.dig("double", :points)
            doubles -= 1
          end
          if triples.positive?
            points += PowerUp::SOLO.dig("triple", :points)
            triples -= 1
          end
          if boosts.positive?
            points += PowerUp::SOLO.dig("boost", :points)
            boosts -= 1
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
