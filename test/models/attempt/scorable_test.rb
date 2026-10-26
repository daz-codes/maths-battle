require "test_helper"

class Attempt::ScorableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  def game(*results) = Attempt.new(user: @user, topic: "times_tables", results: results.map(&:stringify_keys))
  def right(ms) = { correct: true, ms: ms }
  def wrong = { correct: false, ms: 1_000 }

  test "a right answer earns 10, with 10 more for a quick one and 20 for a lightning one; a wrong one loses 5" do
    assert_equal({ right: 30, speed: 30, combo: 0, wrong: -5, longest_run: 2 }, game(right(2_500), right(1_500), wrong, right(800)).score_tally)
    assert_equal 10 + 20 - 5 + 30, game(right(2_500), right(1_500), wrong, right(800)).points
  end

  test "what counts as quick depends on the topic" do
    assert_equal :lightning, Attempt.speed_of({ "ms" => 2_500 }, Equations)
    assert_equal :quick, Attempt.speed_of({ "ms" => 5_000 }, Functions)
    assert_equal :quick, Attempt.speed_of({ "ms" => 8_000 }, SimultaneousEquations)
    assert_nil Attempt.speed_of({ "ms" => 12_000 }, SimultaneousEquations)
    Topic::ALL.each { |topic| assert_operator topic.gem_times[:lightning], :<, topic.gem_times[:quick], topic.title }
  end

  test "right answers in a row multiply what each earns: ×2 from the 5th, ×3 from the 10th, ×4 from the 20th; a wrong one starts again" do
    assert_equal [ 1, 1, 2, 2, 3, 3, 4 ], [ 1, 4, 5, 9, 10, 19, 20 ].map { Attempt.multiplier_for(_1) }

    ten = game(*Array.new(10) { right(2_500) })
    assert_equal 4 * 10 + 5 * 20 + 30, ten.points
    assert_equal({ right: 100, speed: 0, combo: 70, wrong: 0, longest_run: 10 }, ten.score_tally)

    broken = game(*Array.new(4) { right(2_500) }, wrong, *Array.new(5) { right(800) })
    assert_equal 40 - 5 + 4 * 30 + 60, broken.points, "the run starts again after the wrong one, so only its 5th is doubled"
    assert_equal 5, broken.score_tally[:longest_run]
  end

  test "a game never comes to less than nothing, and a review's answers earn none" do
    assert_equal 0, game(wrong, wrong, right(2_500)).points
    assert_equal 0, Attempt.new(user: @user, mode: "review", results: [ right(800).stringify_keys ]).points
  end

  test "a game's score is its answers', saved with it, with how many were right; no bonuses on top" do
    attempt = Attempt.record!(user: @user, results: answers([ 2, 3, 6 ], [ 2, 4, 9 ], ms: 1_500) + answers([ 2, 5, 10 ], ms: 500))
    assert_equal [ 20 - 5 + 30, 2, 3 ], [ attempt.score, attempt.correct, attempt.answered ], "two right, one wrong"
    assert_equal attempt.score, attempt.best_score, "a first game is its own best"
  end

  test "the score as it stood after each answer, as the game showed it" do
    assert_equal [ 30, 25, 35, 30 ], game(right(800), wrong, right(2_500), wrong).running_scores
    assert_equal [ 0, 5 ], game(wrong, right(2_500)).running_scores, "shown as nothing while below it, as the game counts it"
  end

  test "a game's best score and most right are kept with it, as they stood then" do
    Attempt.record!(user: @user, results: answers(*right_answers(6), ms: 500))
    slower = Attempt.record!(user: @user, results: answers(*right_answers(8), ms: 2_500))
    assert slower.score < slower.best_score, "more right, but slower"
    assert_equal 8, slower.best_correct
    assert_not slower.new_high_score
  end

  test "games played before the score was points are scored by the same rules" do
    require Rails.root.join("db/migrate/support/points_backfill")
    attempt = Attempt.record!(user: @user, results: answers(*right_answers(12), ms: 900) + answers([ 2, 3, 7 ]) + answers(*right_answers(6), ms: 1_500))
    assert_equal attempt.score, PointsBackfill.new(nil).points(attempt.topic, attempt.results)
    # Topics there were then (sequences came later)
    Topic::ALL.select { PointsBackfill::SPEEDS.key?(_1.key) }.each { |topic| assert_equal topic.gem_times.values_at(:lightning, :quick), PointsBackfill::SPEEDS.fetch(topic.key), topic.title }
  end

  test "gems are still kept, though not shown: the score with bonuses on top" do
    bronze = Attempt.record!(user: @user, results: answers(*Array.new(20) { [ 2, 3, 6 ] }, ms: 2_500))
    assert_equal({ perfect: 50, high_score: 50, level_up: 100 }, bronze.gem_bonuses)
    assert_equal bronze.score + 200, bronze.gems
  end
end
