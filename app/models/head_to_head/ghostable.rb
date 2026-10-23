# The challenger's game, replayed as a ghost while the opponent plays: when in the minute each of their right
# answers came. Each answer's time runs from its question showing to the answer being checked, so a wrong
# answer's pause to show the right one (WRONG_PAUSE in the game) is added back to keep the ghost on the clock
module HeadToHead::Ghostable
  extend ActiveSupport::Concern

  WRONG_PAUSE_MS = 400

  # { name: "Ada", times: [ 1200, 2650, … ] }, the ms into the minute at each right answer
  def ghost
    return unless sent?

    times = []
    challenger_attempt.results.reduce(0) do |elapsed, result|
      elapsed += result["ms"]
      times << elapsed if result["correct"]
      result["correct"] ? elapsed : elapsed + WRONG_PAUSE_MS
    end
    { name: challenger.display_name, times: times }
  end
end
