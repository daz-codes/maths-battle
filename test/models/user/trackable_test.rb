require "test_helper"

class User::TrackableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  def stat(fact, right, wrong, ms)
    @user.fact_stats.create!(topic: "times_tables", level: 2, fact: fact, correct_count: right, wrong_count: wrong, correct_ms: ms)
  end

  test "a fact counts toward both its tables, and a square once" do
    stat("7x8", 3, 1, 6000)
    stat("7x7", 1, 1, 1000)
    tables = @user.group_stats(TimesTables, 2).index_by(&:label)

    assert_equal [ 4, 6 ], [ tables["7×"].right, tables["7×"].answered ]
    assert_equal 67, tables["7×"].percent
    assert_equal 1750, tables["7×"].average_ms
    assert_equal [ 3, 4 ], [ tables["8×"].right, tables["8×"].answered ]
    assert_nil tables["9×"].percent
  end

  test "best table on accuracy then speed, and the one needing most practice" do
    stat("2x3", 10, 0, 20_000) # 2× and 3×: all right, 2s
    stat("4x6", 9, 1, 13_500)  # 4× and 6×: 90%, 1.5s
    stat("6x7", 5, 5, 15_000)  # 6× now worse, 7×: 50%
    stat("5x5", 10, 0, 10_000) # 5×: all right, 1s: beats 2× and 3× on speed

    assert_equal "5×", @user.best_group(TimesTables, 2).label
    assert_equal "7×", @user.group_needing_practice(TimesTables, 2).label
  end

  test "rankings ignore the trivial tables and tables with too few answers" do
    stat("1x10", 20, 0, 10_000)
    stat("8x9", 2, 2, 2_000)
    stat("3x4", 6, 0, 9_000)
    stat("2x5", 3, 0, 3_000)

    # Only 3× and 4× (from 3×4) qualify: 1× and 10× are trivial, 8× and 9× have 4 answers each
    assert_equal [ "3×", "4×" ], [ @user.best_group(TimesTables, 2).label, @user.group_needing_practice(TimesTables, 2).label ]
  end

  test "average score counts real games only" do
    games = [ 10, 20 ].map { |right| Attempt.record!(user: @user, results: answers(*right_answers(right))) }
    Attempt.record!(user: @user, results: answers(*right_answers(2)))

    assert_equal (games.sum(&:score) / 2.0).round, @user.average_score(TimesTables, 1), "the 2 answer game is too short to count"
    assert_nil User.new.average_score(TimesTables, 1)
  end

  test "flags tables much slower than the player's usual" do
    %w[2x3 3x4 4x5 5x6].each { stat(_1, 4, 0, 8000) }
    stat("8x9", 4, 0, 24_000)
    tables = @user.group_stats(TimesTables, 2).index_by(&:label)

    assert tables["9×"].slow?
    assert_not tables["3×"].slow?
  end
end
