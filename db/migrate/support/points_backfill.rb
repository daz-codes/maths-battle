# A snapshot of the October 2026 scoring rules, to score games already played from their saved answers. Historical
# migrations must not load application models: their callbacks and scopes can depend on columns which have not
# been migrated yet. A right answer is 10, with 10 more if quick and 20 if lightning fast, all multiplied by the run
# of right answers (×2 from the 5th, ×3 from the 10th, ×4 from the 20th); a wrong one is −5 and ends the run. A game
# never scores less than nothing, and a review, with no clock, scores nothing
class PointsBackfill
  SPEEDS = {
    "addition" => [ 2_000, 4_000 ], "times_tables" => [ 1_000, 2_000 ], "division" => [ 1_500, 3_000 ],
    "negatives" => [ 2_000, 4_000 ], "fractions" => [ 4_000, 8_000 ], "percentages" => [ 3_000, 6_000 ],
    "conversions" => [ 3_000, 6_000 ], "equations" => [ 3_000, 6_000 ], "functions" => [ 3_000, 6_000 ],
    "simultaneous" => [ 5_000, 10_000 ], "simultaneous_equations" => [ 5_000, 10_000 ]
  }.freeze
  COMBOS = { 20 => 4, 10 => 3, 5 => 2 }.freeze

  def initialize(connection)
    @connection = connection
  end

  # Each game's score, and the best at its level when it was played (the score itself, for games with no level's best)
  def run
    bests = Hash.new(0)
    @connection.select_rows("SELECT id, user_id, topic, level, mode, results FROM attempts ORDER BY id").each do |id, user_id, topic, level, mode, results|
      score = mode == "review" ? 0 : points(topic, JSON.parse(results.presence || "[]"))
      best = if mode == "practice" || mode == "challenge"
        bests[[ user_id, topic, mode == "practice" ? level : mode ]] = [ bests[[ user_id, topic, mode == "practice" ? level : mode ]], score ].max
      else
        score
      end
      @connection.execute("UPDATE attempts SET score = #{Integer(score)}, best_score = #{Integer(best)} WHERE id = #{Integer(id)}")
    end
  end

  def points(topic, results)
    lightning, quick = SPEEDS.fetch(topic, [ 0, 0 ])
    in_a_row = 0
    total = results.sum do |result|
      next (in_a_row = 0) - 5 unless result["correct"]

      in_a_row += 1
      ms = result["ms"].to_i
      speed = ms < lightning ? 20 : ms < quick ? 10 : 0
      (10 + speed) * (COMBOS.find { |from, _| in_a_row >= from }&.last || 1)
    end
    [ total, 0 ].max
  end
end
