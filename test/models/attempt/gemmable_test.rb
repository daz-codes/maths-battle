require "test_helper"

class Attempt::GemmableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  def gems(ms, correct: true, topic: TimesTables) = Attempt.gems_for({ "correct" => correct, "ms" => ms }, topic)

  test "a right answer earns 10, a quick one 20, and a lightning one 30" do
    assert_equal 10, gems(2_500)
    assert_equal 20, gems(1_500)
    assert_equal 30, gems(800)
    assert_equal 0, gems(800, correct: false)
  end

  test "what counts as quick depends on the topic" do
    assert_equal 30, gems(2_500, topic: Equations)
    assert_equal 20, gems(5_000, topic: Functions)
    assert_equal 20, gems(8_000, topic: SimultaneousEquations)
    assert_equal 10, gems(12_000, topic: SimultaneousEquations)
    Topic::ALL.each { |topic| assert_operator topic.gem_times[:lightning], :<, topic.gem_times[:quick], topic.title }
  end

  test "a game's stars are its answers' stars, saved with it" do
    attempt = Attempt.record!(user: @user, results: answers([ 2, 3, 6 ], [ 2, 4, 9 ], ms: 1_500) + answers([ 2, 5, 10 ], ms: 500))
    assert_equal 20 + 0 + 30 + 50, attempt.gems, "two right, one wrong, and a first game is a new high score"
    assert_equal({ high_score: 50 }, attempt.gem_bonuses)
  end

  test "bonuses for a perfect game, a new high score and levelling up" do
    first = Attempt.record!(user: @user, results: answers(*Array.new(4) { [ 2, 3, 6 ] }, ms: 2_500))
    bronze = Attempt.record!(user: @user, results: answers(*Array.new(20) { [ 2, 3, 6 ] }, ms: 2_500))
    again = Attempt.record!(user: @user, results: answers(*Array.new(20) { [ 2, 3, 6 ] }, ms: 2_500))

    assert_equal({ high_score: 50 }, first.gem_bonuses, "4 answers is too few for a perfect game, or a bronze")
    assert_equal({ perfect: 50, high_score: 50, level_up: 100 }, bronze.gem_bonuses)
    assert_equal({ perfect: 50 }, again.gem_bonuses)
    assert_equal 20 * 10 + 50 + 50 + 100, bronze.gems
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
