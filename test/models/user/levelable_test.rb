require "test_helper"

class User::LevelableTest < ActiveSupport::TestCase
  NEEDED = User::Levelable::GOOD_GAMES_TO_LEVEL_UP

  setup { @user = users(:ada) }

  # Functions levels up by good games: 20 answered, good when 18 or more are right
  def play(level:, right:)
    results = Array.new(20) { |i| { type: "x+a", a: 2, n: 3, given: i < right ? "5" : "6", ms: 1000 } }
    Attempt.record!(user: @user, topic: "functions", level: level, results: results)
  end

  # Times tables levels up by medals: a score of 10 is bronze
  def practise(level:, score:, **options)
    Attempt.record!(user: @user, level: level, results: answers(*Array.new(score) { [ 2, 3, 6 ] }), **options)
  end

  test "new players start at level 1" do
    assert_equal 1, @user.unlocked_level(Functions)
    assert_equal "Negatives", @user.next_level(Functions)[:name]
    assert_equal NEEDED, @user.good_games_to_level_up(Functions)
  end

  test "three good games unlock the next level, and the last one says so" do
    (NEEDED - 1).times { play(level: 1, right: 19) }
    assert_equal 1, @user.unlocked_level(Functions)
    assert_equal 1, @user.good_games_to_level_up(Functions)

    last = play(level: 1, right: 18)
    assert last.levelled_up
    assert_equal 2, @user.unlocked_level(Functions)
    assert_equal NEEDED, @user.good_games_to_level_up(Functions), "counting starts again at the new level"
  end

  test "games under 90% right or with fewer than 10 answered don't count" do
    NEEDED.times { play(level: 1, right: 17) }
    3.times { Attempt.record!(user: @user, topic: "functions", results: [ { type: "x+a", a: 2, n: 3, given: "5", ms: 1000 } ] * 9) }

    assert_equal 1, @user.unlocked_level(Functions)
    assert_equal NEEDED, @user.good_games_to_level_up(Functions)
  end

  test "games saved elsewhere show once the player is reloaded" do
    assert_equal 1, @user.unlocked_level(Functions)
    elsewhere = User.find(@user.id)
    NEEDED.times { Attempt.record!(user: elsewhere, topic: "functions", results: [ { type: "x+a", a: 2, n: 3, given: "5", ms: 1000 } ] * 20) }

    assert_equal 2, @user.reload.unlocked_level(Functions)
  end

  test "a locked level can't be played" do
    assert_raises(Attempt::Invalid) { play(level: 2, right: 20) }
    assert_raises(Attempt::Invalid) { practise(level: 2, score: 20) }
  end

  test "unlocked levels can be played again, without unlocking anything twice" do
    NEEDED.times { play(level: 1, right: 20) }
    another = play(level: 1, right: 20)

    assert_not another.levelled_up
    assert_equal 2, @user.unlocked_level(Functions)
  end

  test "times tables: a bronze unlocks the next level, and the game that earns it says so" do
    assert_not practise(level: 1, score: 9).levelled_up
    assert_equal 1, @user.unlocked_level(TimesTables)
    assert_nil @user.medal(TimesTables, 1)

    bronze = practise(level: 1, score: 10)
    assert bronze.levelled_up
    assert_equal :bronze, bronze.new_medal
    assert_equal 2, @user.unlocked_level(TimesTables)
  end

  test "times tables: a level keeps its best medal, and a better one is new" do
    practise(level: 1, score: 12)
    silver = practise(level: 1, score: 22)
    worse = practise(level: 1, score: 15)
    gold = practise(level: 1, score: 31)

    assert_equal [ :silver, nil, :gold ], [ silver.new_medal, worse.new_medal, gold.new_medal ]
    assert_not silver.levelled_up, "only the first bronze unlocks the next level"
    assert_equal :gold, @user.medal(TimesTables, 1)
  end

  test "times tables: a daily challenge earns no medal and unlocks nothing" do
    challenge = practise(level: 1, score: 25, daily_challenge: true)
    assert_nil challenge.medal
    assert_not challenge.levelled_up
    assert_equal 1, @user.unlocked_level(TimesTables)
  end

  test "players who'd already played the 2–12 tables keep level 2" do
    @user.attempts.create!(topic: "times_tables", level: 2, results: [], score: 0, answered: 0)
    assert_equal 2, @user.unlocked_level(TimesTables)
  end

  test "the top level has nothing after it" do
    (1..4).each { |level| practise(level: level, score: 10) }
    assert_equal 5, @user.unlocked_level(TimesTables)
    assert_nil @user.next_level(TimesTables)
  end
end
