require "test_helper"

class AttemptTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  test "the score is worked out on the server" do
    attempt = Attempt.record!(user: @user, results: answers([ 7, 8, 56 ], [ 6, 7, 41 ], [ 9, 9, 81 ]).map { |r| r.merge(correct: true, score: 99) })

    assert_equal 2, attempt.score
    assert_equal 3, attempt.answered
    assert_equal [ true, false, true ], attempt.results.map { |r| r["correct"] }
    assert_equal({ "a" => 6, "b" => 7, "given" => 41, "correct" => false, "ms" => 1000 }, attempt.results[1])
  end

  test "each attempt gets an unguessable share token" do
    attempt = Attempt.record!(user: @user, results: answers([ 2, 2, 4 ]))
    assert_operator attempt.share_token.length, :>=, 24
  end

  test "rejects too many answers" do
    assert_raises(Attempt::Invalid) { Attempt.record!(user: @user, results: answers(*Array.new(151) { [ 2, 2, 4 ] }, ms: 100)) }
  end

  test "rejects answers that took longer than the test" do
    assert_raises(Attempt::Invalid) { Attempt.record!(user: @user, results: answers(*right_answers(10), ms: 7000)) }
    assert_raises(Attempt::Invalid) { Attempt.record!(user: @user, results: answers([ 2, 2, 4 ], ms: -5)) }
  end

  test "rejects questions outside the tables and nonsense answers" do
    assert_raises(Attempt::Invalid) { Attempt.record!(user: @user, results: answers([ 13, 2, 26 ])) }
    assert_raises(Attempt::Invalid) { Attempt.record!(user: @user, results: answers([ 2, 2, "four" ])) }
    assert_raises(Attempt::Invalid) { Attempt.record!(user: @user, results: [ "7x8=56" ]) }
    assert_raises(Attempt::Invalid) { Attempt.record!(user: @user, results: answers([ 2, 2, 4 ]), topic: "spelling") }
  end

  test "an invalid attempt saves nothing" do
    assert_no_difference -> { Attempt.count } do
      assert_raises(Attempt::Invalid) { Attempt.record!(user: @user, results: answers([ 2, 2, 4 ], [ 0, 2, 0 ])) }
    end
  end

  test "updates the fact stats, treating both orders as one fact" do
    Attempt.record!(user: @user, results: answers([ 7, 8, 56 ], [ 8, 7, 54 ], [ 3, 4, 12 ]))

    seven_eight = @user.fact_stats.find_by!(topic: "times_tables", fact: "7x8")
    assert_equal [ 1, 1, 50 ], [ seven_eight.correct_count, seven_eight.wrong_count, seven_eight.percent_correct ]
    assert_equal 100, @user.fact_stats.find_by!(fact: "3x4").percent_correct

    Attempt.record!(user: @user, results: answers([ 8, 7, 56 ]))
    assert_equal 67, seven_eight.reload.percent_correct
  end

  test "keeps the average time of right answers, capping very long ones" do
    Attempt.record!(user: @user, results: [ { a: 7, b: 8, given: 56, ms: 2000 }, { a: 8, b: 7, given: 56, ms: 4000 }, { a: 7, b: 8, given: 1, ms: 9000 } ])
    seven_eight = @user.fact_stats.find_by!(fact: "7x8")
    assert_equal 3000, seven_eight.average_correct_ms, "wrong answers aren't timed"

    Attempt.record!(user: @user, results: [ { a: 7, b: 8, given: 56, ms: 30_000 } ])
    assert_equal 16_000, seven_eight.reload.correct_ms, "a 30 second answer counts as 10"
  end

  test "counts toward the streak when enough questions were answered" do
    attempt = Attempt.record!(user: @user, results: answers(*right_answers(5)))

    assert_equal 1, @user.reload.current_streak
    assert_equal 1, attempt.streak
  end

  test "starting and walking away doesn't count toward the streak" do
    attempt = Attempt.record!(user: @user, results: answers(*right_answers(4)))

    assert_equal 0, @user.reload.current_streak
    assert_equal 0, attempt.streak
  end

  test "a game uploaded twice is only recorded once" do
    first = Attempt.record!(user: @user, results: answers(*right_answers(6)), client_id: "abc-123")

    assert_no_difference -> { Attempt.count } do
      assert_equal first, Attempt.record!(user: @user, results: answers(*right_answers(6)), client_id: "abc-123")
    end
    assert_equal 6, @user.fact_stats.sum(:correct_count), "stats only counted once"
  end

  test "different players can use the same client id" do
    Attempt.record!(user: @user, results: answers([ 2, 2, 4 ]), client_id: "same")
    assert_difference -> { Attempt.count } do
      Attempt.record!(user: users(:bob), results: answers([ 2, 2, 4 ]), client_id: "same")
    end
  end

  test "keeps when a game was played, counting the day in the player's time zone" do
    travel_to Time.utc(2026, 10, 16, 9) do
      @user.update!(time_zone: "Eastern Time (US & Canada)")
      attempt = Attempt.record!(user: @user, results: answers([ 2, 2, 4 ]), played_at: "2026-10-16T02:30:00Z")

      assert_equal Time.utc(2026, 10, 16, 2, 30), attempt.played_at
      assert_equal Date.new(2026, 10, 15), attempt.played_on, "half past ten at night on the 15th in New York"
    end
  end

  test "a play time in the future or too long ago counts as now" do
    travel_to Time.utc(2026, 10, 16, 9) do
      assert_equal Time.current, Attempt.record!(user: @user, results: answers([ 2, 2, 4 ]), played_at: "2026-10-20T09:00:00Z").played_at
      assert_equal Time.current, Attempt.record!(user: @user, results: answers([ 2, 2, 4 ]), played_at: "2026-08-01T09:00:00Z").played_at
      assert_equal Time.current, Attempt.record!(user: @user, results: answers([ 2, 2, 4 ]), played_at: "nonsense").played_at
    end
  end

  test "records a new high score" do
    first = Attempt.record!(user: @user, results: answers(*right_answers(6)))
    worse = Attempt.record!(user: @user, results: answers(*right_answers(5)))

    assert first.new_high_score
    assert_not worse.new_high_score
    assert_equal 6, @user.best_score(TimesTables)
  end
end
