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
end
