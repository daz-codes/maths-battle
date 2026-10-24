require "test_helper"

class Attempt::GemmableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  def game(*results) = Attempt.new(user: @user, topic: "times_tables", results: results.map(&:stringify_keys))
  def right(ms) = { correct: true, ms: ms }
  def wrong = { correct: false, ms: 1_000 }

  test "a right answer earns 10, with 10 more for a quick one and 20 for a lightning one; a wrong one loses 5" do
    assert_equal({ right: 30, speed: 30, combo: 0, wrong: -5, longest_run: 2 }, game(right(2_500), right(1_500), wrong, right(800)).gem_tally)
    assert_equal 10 + 20 - 5 + 30, game(right(2_500), right(1_500), wrong, right(800)).answer_gems
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
    assert_equal 4 * 10 + 5 * 20 + 30, ten.answer_gems
    assert_equal({ right: 100, speed: 0, combo: 70, wrong: 0, longest_run: 10 }, ten.gem_tally)

    broken = game(*Array.new(4) { right(2_500) }, wrong, *Array.new(5) { right(800) })
    assert_equal 40 - 5 + 4 * 30 + 60, broken.answer_gems, "the run starts again after the wrong one, so only its 5th is doubled"
    assert_equal 5, broken.gem_tally[:longest_run]
  end

  test "a game never comes to less than nothing, and a review's answers earn none" do
    assert_equal 0, game(wrong, wrong, right(2_500)).answer_gems
    assert_equal 0, Attempt.new(user: @user, mode: "review", results: [ right(800).stringify_keys ]).answer_gems
  end

  test "a game's stars are its answers' stars, saved with it" do
    attempt = Attempt.record!(user: @user, results: answers([ 2, 3, 6 ], [ 2, 4, 9 ], ms: 1_500) + answers([ 2, 5, 10 ], ms: 500))
    assert_equal 20 - 5 + 30 + 50, attempt.gems, "two right, one wrong, and a first game is a new high score"
    assert_equal({ high_score: 50 }, attempt.gem_bonuses)
  end

  test "bonuses for a perfect game, a new high score and levelling up" do
    first = Attempt.record!(user: @user, results: answers(*Array.new(4) { [ 2, 3, 6 ] }, ms: 2_500))
    bronze = Attempt.record!(user: @user, results: answers(*Array.new(20) { [ 2, 3, 6 ] }, ms: 2_500))
    again = Attempt.record!(user: @user, results: answers(*Array.new(20) { [ 2, 3, 6 ] }, ms: 2_500))

    assert_equal({ high_score: 50 }, first.gem_bonuses, "4 answers is too few for a perfect game, or a bronze")
    assert_equal({ perfect: 50, high_score: 50, level_up: 100 }, bronze.gem_bonuses)
    assert_equal({ perfect: 50 }, again.gem_bonuses)
    assert_equal 4 * 10 + 5 * 20 + 10 * 30 + 1 * 40 + 50 + 50 + 100, bronze.gems
  end

  test "a player's stars are all their games' stars" do
    2.times { Attempt.record!(user: @user, results: answers(*right_answers(5), ms: 2_500)) }
    assert_equal Attempt.where(user: @user).sum(:gems), User.find(@user.id).gems
    assert_equal 0, User.new.gems
  end

  test "worked out again from a saved game, as the backfill does, it comes to the same" do
    attempt = Attempt.record!(user: @user, results: answers(*right_answers(8), ms: 900))
    assert_equal attempt.gems, Attempt.find(attempt.id).count_gems
  end
end
