require "test_helper"

# Every topic levels up by medals: a level's practice earns one for its score, and a bronze unlocks the next
class User::LevelableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  def practise(level:, score:, topic: TimesTables, **options)
    Attempt.record!(user: @user, topic: topic.key, level: level, results: [ EASY_QUESTIONS.fetch(topic) ] * score, **options)
  end

  test "new players start at level 1" do
    assert_equal 1, @user.unlocked_level(TimesTables)
    assert_equal "Tables 2–12", @user.next_level(TimesTables)[:name]
  end

  test "a bronze unlocks the next level, and the game that earns it says so" do
    assert_not practise(level: 1, score: 9).levelled_up
    assert_equal 1, @user.unlocked_level(TimesTables)
    assert_nil @user.medal(TimesTables, 1)

    bronze = practise(level: 1, score: 10)
    assert bronze.levelled_up
    assert_equal :bronze, bronze.new_medal
    assert_equal 2, @user.unlocked_level(TimesTables)
  end

  test "each topic sets its own medal scores" do
    assert_not practise(topic: Functions, level: 1, score: 5).levelled_up
    assert practise(topic: Functions, level: 1, score: 6).levelled_up, "6 is bronze for functions"
    assert practise(topic: SimultaneousEquations, level: 1, score: 4).levelled_up, "4 is bronze for simultaneous equations"
    assert_equal 2, @user.unlocked_level(Functions)

    Topic::ALL.each do |topic|
      assert_operator topic.medals[:bronze], :<, topic.medals[:silver], topic.title
      assert_operator topic.medals[:silver], :<, topic.medals[:gold], topic.title
    end
  end

  test "a level keeps its best medal, and a better one is new" do
    practise(level: 1, score: 12)
    silver = practise(level: 1, score: 22)
    worse = practise(level: 1, score: 15)
    gold = practise(level: 1, score: 31)

    assert_equal [ :silver, nil, :gold ], [ silver.new_medal, worse.new_medal, gold.new_medal ]
    assert_not silver.levelled_up, "only the first bronze unlocks the next level"
    assert_equal :gold, @user.medal(TimesTables, 1)
  end

  test "a daily challenge earns no medal and unlocks nothing" do
    challenge = practise(level: 1, score: 25, daily_challenge: true)
    assert_nil challenge.medal
    assert_not challenge.levelled_up
    assert_equal 1, @user.unlocked_level(TimesTables)
  end

  test "games saved elsewhere show once the player is reloaded" do
    assert_equal 1, @user.unlocked_level(TimesTables)
    Attempt.record!(user: User.find(@user.id), results: answers(*Array.new(10) { [ 2, 3, 6 ] }))

    assert_equal 2, @user.reload.unlocked_level(TimesTables)
  end

  test "a locked level can't be played" do
    assert_raises(Attempt::Invalid) { practise(level: 2, score: 20) }
  end

  test "players who'd already played a level keep it" do
    @user.attempts.create!(topic: "times_tables", level: 2, results: [], score: 0, answered: 0)
    assert_equal 2, @user.unlocked_level(TimesTables)
  end

  test "the top level has nothing after it" do
    (1..4).each { |level| practise(level: level, score: 10) }
    assert_equal 5, @user.unlocked_level(TimesTables)
    assert_nil @user.next_level(TimesTables)
  end
end
