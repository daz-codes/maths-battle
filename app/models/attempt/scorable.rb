# A game's score: every right answer scores, a quick one more for its speed on top, and a wrong answer loses a few.
# Right answers in a row build a combo that multiplies what each scores, and a wrong one ends it. Worked out here
# from the checked answers, so what floats up during the game is just for show, and a game never scores less than
# nothing. A review has no clock, so it scores nothing: it's how many were right that counts (Recordable's correct)
module Attempt::Scorable
  extend ActiveSupport::Concern

  RIGHT = 10
  SPEED = { quick: 10, lightning: 20 }
  WRONG = -5
  # Right answers in a row: ×2 from the 5th, ×3 from the 10th, ×4 from the 20th
  COMBOS = { 20 => 4, 10 => 3, 5 => 2 }
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
    def scoring_rules(topic)
      { right: RIGHT, speed: SPEED, wrong: WRONG, combos: COMBOS.sort.to_h, times: topic.gem_times }
    end
  end

  # Where the score came from, like { right: 200, speed: 150, combo: 180, wrong: -10 }, and the longest run
  def score_tally
    @score_tally ||= begin
      tally, longest = { right: 0, speed: 0, combo: 0, wrong: 0 }, 0
      each_answer_scored do |part|
        tally.merge!(part.slice(*tally.keys)) { |_, total, more| total + more }
        longest = [ longest, part[:in_a_row] ].max
      end
      tally.merge(longest_run: longest)
    end
  end

  # The score as it stood after each answer, as the game showed it (never below nothing)
  def running_scores
    total = 0
    [].tap { |scores| each_answer_scored { |part| scores << [ (total += part.values_at(:right, :speed, :combo, :wrong).sum), 0 ].max } }
  end

  # The score its answers make
  def points
    return 0 if review?

    [ score_tally.except(:longest_run).values.sum, 0 ].max
  end

  private
    # What each answer scored: { right:, speed:, combo: } for a right one, { wrong: } for a wrong one, with the run it made
    def each_answer_scored
      in_a_row = 0
      results.each do |result|
        if result["correct"]
          in_a_row += 1
          speed = SPEED.fetch(self.class.speed_of(result, topic_module), 0)
          yield({ right: RIGHT, speed: speed, combo: (RIGHT + speed) * (self.class.multiplier_for(in_a_row) - 1), wrong: 0, in_a_row: in_a_row })
        else
          in_a_row = 0
          yield({ right: 0, speed: 0, combo: 0, wrong: WRONG, in_a_row: 0 })
        end
      end
    end
end
