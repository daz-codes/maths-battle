require "test_helper"

class Attempt::StarrableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  def stars(ms, correct: true, topic: TimesTables) = Attempt.stars_for({ "correct" => correct, "ms" => ms }, topic)

  test "a right answer earns 10, a quick one 20, and a lightning one 30" do
    assert_equal 10, stars(2_500)
    assert_equal 20, stars(1_500)
    assert_equal 30, stars(800)
    assert_equal 0, stars(800, correct: false)
  end

  test "what counts as quick depends on the topic" do
    assert_equal 30, stars(2_500, topic: Equations)
    assert_equal 20, stars(5_000, topic: Functions)
    assert_equal 20, stars(8_000, topic: SimultaneousEquations)
    assert_equal 10, stars(12_000, topic: SimultaneousEquations)
    Topic::ALL.each { |topic| assert_operator topic.star_times[:lightning], :<, topic.star_times[:quick], topic.title }
  end

  test "a game's stars are its answers' stars, saved with it" do
    attempt = Attempt.record!(user: @user, results: answers([ 2, 3, 6 ], [ 2, 4, 9 ], ms: 1_500) + answers([ 2, 5, 10 ], ms: 500))
    assert_equal 20 + 0 + 30 + 50, attempt.stars, "two right, one wrong, and a first game is a new high score"
    assert_equal({ high_score: 50 }, attempt.star_bonuses)
  end

  test "bonuses for a perfect game, a new high score and levelling up" do
    first = Attempt.record!(user: @user, results: answers(*Array.new(4) { [ 2, 3, 6 ] }, ms: 2_500))
    bronze = Attempt.record!(user: @user, results: answers(*Array.new(20) { [ 2, 3, 6 ] }, ms: 2_500))
    again = Attempt.record!(user: @user, results: answers(*Array.new(20) { [ 2, 3, 6 ] }, ms: 2_500))

    assert_equal({ high_score: 50 }, first.star_bonuses, "4 answers is too few for a perfect game, or a bronze")
    assert_equal({ perfect: 50, high_score: 50, level_up: 100 }, bronze.star_bonuses)
    assert_equal({ perfect: 50 }, again.star_bonuses)
    assert_equal 20 * 10 + 50 + 50 + 100, bronze.stars
  end

  test "a player's stars are all their games' stars" do
    2.times { Attempt.record!(user: @user, results: answers(*right_answers(5), ms: 2_500)) }
    assert_equal Attempt.where(user: @user).sum(:stars), User.find(@user.id).stars
    assert_equal 0, User.new.stars
  end

  test "worked out again from a saved game, as the backfill does, it comes to the same" do
    attempt = Attempt.record!(user: @user, results: answers(*right_answers(8), ms: 900))
    assert_equal attempt.stars, Attempt.find(attempt.id).count_stars
  end
end
