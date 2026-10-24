# The challenger's game, replayed as a ghost while the opponent plays: their score as it went up through the minute.
# Each answer's time runs from its question showing to the answer being checked, so a wrong answer's pause to show
# the right one (WRONG_PAUSE in the game) is added back to keep the ghost on the clock
module HeadToHead::Ghostable
  extend ActiveSupport::Concern

  WRONG_PAUSE_MS = 400

  # { name: "Ada", steps: [ [ 1200, 30 ], [ 2650, 50 ], … ] }: the ms into the minute at each answer, and their score then
  def ghost
    return unless sent?

    scores = challenger_attempt.running_scores
    elapsed = 0
    steps = challenger_attempt.results.each_with_index.map do |result, index|
      elapsed += result["ms"]
      [ elapsed, scores[index] ].tap { elapsed += WRONG_PAUSE_MS unless result["correct"] }
    end
    { name: challenger.display_name, steps: steps }
  end
end
