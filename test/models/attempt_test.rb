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
    travel_to Time.zone.local(2026, 10, 15, 9) do
      Attempt.record!(user: @user, results: answers([ 7, 8, 56 ], [ 8, 7, 54 ], [ 3, 4, 12 ]))
    end

    seven_eight = @user.fact_stats.find_by!(topic: "times_tables", fact: "7x8")
    assert_equal 1, seven_eight.correct_count
    assert_equal 1, seven_eight.wrong_count
    assert_equal Time.zone.local(2026, 10, 15, 9), seven_eight.last_wrong_at

    three_four = @user.fact_stats.find_by!(fact: "3x4")
    assert_equal [ 1, 0, nil ], [ three_four.correct_count, three_four.wrong_count, three_four.last_wrong_at ]

    Attempt.record!(user: @user, results: answers([ 8, 7, 56 ]))
    assert_equal 2, seven_eight.reload.correct_count
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

  test "records a new high score" do
    first = Attempt.record!(user: @user, results: answers(*right_answers(6)))
    worse = Attempt.record!(user: @user, results: answers(*right_answers(5)))

    assert first.new_high_score
    assert_not worse.new_high_score
    assert_equal 6, @user.reload.high_score
  end
end
