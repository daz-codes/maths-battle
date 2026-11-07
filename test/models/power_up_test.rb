require "test_helper"

class PowerUpTest < ActiveSupport::TestCase
  def right(count) = Array.new(count) { { "correct" => true } }

  test "Triple points triples the next five right answers, before any Double" do
    tally = Attempt.tally(right(6), [ { "kind" => "triple", "at" => 0 }, { "kind" => "double", "at" => 0 } ])
    assert_equal (10 + 20 + 30 + 40 + 50) * 3 + 60 * 2, tally.score
  end

  test "a Boost adds 50 to each of the next five right answers" do
    tally = Attempt.tally(right(6), [ { "kind" => "boost", "at" => 0 } ])
    assert_equal (10 + 20 + 30 + 40 + 50 + 60) + 50 * 5, tally.score
  end

  test "a Bomb takes the score and the streak back to nothing where it hits" do
    tally = Attempt.tally(right(5), [ { "kind" => "bomb", "at" => 3 } ])
    assert_equal 10 + 20, tally.score
    assert_equal [ 10, 30, 60, 10, 30 ], tally.running
  end

  test "drops are never the Bomb: only claiming one far behind can make it one" do
    assert_not_includes PowerUp::DROPPED, "bomb"
    assert_includes PowerUp::DROPPED, "ink"
    assert_includes PowerUp::DROPPED, "mini"
  end

  test "Coins add 100 there and then" do
    tally = Attempt.tally(right(2), [ { "kind" => "coins", "at" => 1 } ])
    assert_equal 10 + 100 + 20, tally.score
  end

  test "a Superstar counts the next five answers as right, whatever was typed" do
    results = [ { "correct" => true } ] + Array.new(5) { { "correct" => false } } + [ { "correct" => false } ]
    tally = Attempt.tally(results, [ { "kind" => "star", "at" => 1 } ])
    assert_equal 10 + 20 + 30 + 40 + 50 + 60, tally.score
    assert_equal 6, tally.best_streak
  end

  test "a Superstar's answers still count as wrong in how many were right" do
    attempt = play(users(:ada), rights: [ true ] * 3 + [ false ] * 2 + [ true ] * 7, powers: [ "star" ] * PowerUp::MOST, claims: [ { drop: 1, at: 3 } ])
    assert_equal 10, attempt.correct
    assert_equal (1..12).sum * 10, attempt.score
  end

  test "attacks are told apart from the ones that help whoever claims them" do
    assert PowerUp.attack?("homing")
    assert PowerUp.attack?("mirror")
    assert_not PowerUp.attack?("horn")
    assert_not PowerUp.attack?("star")
    assert_not PowerUp.attack?("coins")
  end

  test "a skipped question scores nothing and leaves the streak as it was" do
    results = [ { "correct" => true }, { "skip" => true, "correct" => false }, { "correct" => true } ]
    assert_equal 10 + 20, Attempt.tally(results, []).score
  end
end
