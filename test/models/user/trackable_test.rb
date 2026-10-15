require "test_helper"

class User::TrackableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  def stat(fact, right, wrong, ms)
    @user.fact_stats.create!(topic: "times_tables", fact: fact, correct_count: right, wrong_count: wrong, correct_ms: ms)
  end

  test "a fact counts toward both its tables, and a square once" do
    stat("7x8", 3, 1, 6000)
    stat("7x7", 1, 1, 1000)
    tables = @user.table_stats.index_by(&:label)

    assert_equal [ 4, 6 ], [ tables["7×"].right, tables["7×"].answered ]
    assert_equal 67, tables["7×"].percent
    assert_equal 1750, tables["7×"].average_ms
    assert_equal [ 3, 4 ], [ tables["8×"].right, tables["8×"].answered ]
    assert_nil tables["9×"].percent
  end

  test "flags tables much slower than the player's usual" do
    %w[2x3 3x4 4x5 5x6].each { stat(_1, 4, 0, 8000) }
    stat("8x9", 4, 0, 24_000)
    tables = @user.table_stats.index_by(&:label)

    assert tables["9×"].slow?
    assert_not tables["3×"].slow?
  end
end
