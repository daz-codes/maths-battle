require "test_helper"

class AttemptTest < ActiveSupport::TestCase
  test "streaks score 10, 20, 30 and a wrong answer starts again at 10" do
    results = [ true, true, true, false, true ].map { |correct| { "correct" => correct } }
    tally = Attempt.tally(results, [])
    assert_equal 10 + 20 + 30 + 10, tally.score
    assert_equal 3, tally.best_streak
    assert_equal [ 10, 30, 60, 60, 70 ], tally.running
  end

  test "a Bonus +10 adds 10 to each of the next five right answers, rather than multiplying them" do
    results = Array.new(7) { { "correct" => true } }
    tally = Attempt.tally(results, [ { "kind" => "double", "at" => 0 } ])
    assert_equal (10 + 20 + 30 + 40 + 50 + 60 + 70) + 10 * 5, tally.score
  end

  test "a streak shield saves the streak from the next wrong answer only" do
    results = [ true, true, false, true, false, true ].map { |correct| { "correct" => correct } }
    tally = Attempt.tally(results, [ { "kind" => "shield", "at" => 1 } ])
    assert_equal 10 + 20 + 30 + 10, tally.score
  end

  test "a streak breaker ends the streak where it hit" do
    results = Array.new(4) { { "correct" => true } }
    tally = Attempt.tally(results, [ { "kind" => "reset", "at" => 2 } ])
    assert_equal 10 + 20 + 10 + 20, tally.score
  end

  test "recording works out the score, streak, top tier and day" do
    attempt = play(users(:ada), rights: [ true, true, true, true, false ])
    assert_equal 4, attempt.correct
    assert_equal 5, attempt.answered
    assert_equal 100, attempt.score
    assert_equal 4, attempt.best_streak
    assert_equal 2, attempt.top_tier
    assert_equal League.today, attempt.played_on
    assert attempt.new_best
  end

  test "a lower score isn't a new best" do
    play(users(:ada), rights: [ true ] * 5)
    assert_not play(users(:ada), rights: [ true ]).new_best
  end

  test "the same game saved twice is recorded once" do
    game = checked_game
    first = Attempt.record!(user: users(:ada), game: game, client_id: "same")
    assert_equal first, Attempt.record!(user: users(:ada), game: game, client_id: "same")
  end

  test "extra time allows a longer game" do
    rights = [ true ] * 12
    dealt = PowerUp::SOLO.keys.map { "time" }.cycle.first(PowerUp::MOST)
    assert_raises(Attempt::Invalid) { play(users(:ada), rights: rights, ms: 10_600) }
    attempt = play(users(:ada), rights: rights, ms: 10_600, powers: dealt, claims: [ { drop: 1, at: 3 } ])
    assert_equal 12, attempt.correct
  end
end
