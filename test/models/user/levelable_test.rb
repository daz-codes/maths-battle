require "test_helper"

class User::LevelableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  # 20 answered: good when 18 or more are right
  def play(level:, right:, topic: "times_tables")
    results = Array.new(20) { |i| i < right ? [ 2, 3, 6 ] : [ 2, 3, 1 ] }
    Attempt.record!(user: @user, topic: topic, level: level, results: answers(*results, ms: 1000))
  end

  test "new players start at level 1" do
    assert_equal 1, @user.unlocked_level(TimesTables)
    assert_equal "Tables 2–12", @user.next_level(TimesTables)[:name]
    assert_equal 5, @user.good_games_to_level_up(TimesTables)
  end

  test "five good games unlock the next level, and the fifth says so" do
    4.times { play(level: 1, right: 19) }
    assert_equal 1, @user.unlocked_level(TimesTables)
    assert_equal 1, @user.good_games_to_level_up(TimesTables)

    fifth = play(level: 1, right: 18)
    assert fifth.levelled_up
    assert_equal 2, @user.unlocked_level(TimesTables)
    assert_equal 5, @user.good_games_to_level_up(TimesTables), "counting starts again at the new level"
  end

  test "games under 90% right or with fewer than 20 answered don't count" do
    5.times { play(level: 1, right: 17) }
    3.times { Attempt.record!(user: @user, results: answers(*Array.new(19) { [ 2, 3, 6 ] })) }

    assert_equal 1, @user.unlocked_level(TimesTables)
    assert_equal 5, @user.good_games_to_level_up(TimesTables)
  end

  test "a locked level can't be played" do
    assert_raises(Attempt::Invalid) { play(level: 2, right: 20) }
  end

  test "unlocked levels can be played again, without unlocking anything twice" do
    5.times { play(level: 1, right: 20) }
    sixth = play(level: 1, right: 20)

    assert_not sixth.levelled_up
    assert_equal 2, @user.unlocked_level(TimesTables)
  end

  test "players who'd already played the 2–12 tables keep level 2" do
    @user.attempts.create!(topic: "times_tables", level: 2, results: [], score: 0, answered: 0)
    assert_equal 2, @user.unlocked_level(TimesTables)
  end

  test "the top level has nothing after it" do
    (1..4).each { |level| 5.times { play(level: level, right: 20) } }
    assert_equal 5, @user.unlocked_level(TimesTables)
    assert_nil @user.next_level(TimesTables)
    assert_equal 1, @user.unlocked_level(Equations), "topics with one level stay at it"
  end
end
