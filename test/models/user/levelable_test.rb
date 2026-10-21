require "test_helper"

# Every topic levels up by stars: a level's practice earns 1 to 3 for its score, and the first star unlocks the next
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
    assert_not practise(level: 1, score: 4).levelled_up
    assert_equal 1, @user.unlocked_level(TimesTables)
    assert_equal 0, @user.stars(TimesTables, 1)

    bronze = practise(level: 1, score: 5)
    assert bronze.levelled_up
    assert_equal 1, bronze.new_stars
    assert_equal 2, @user.unlocked_level(TimesTables)
  end

  test "every topic has 5 for bronze, 10 for silver and 20 for gold" do
    assert_not practise(topic: Functions, level: 1, score: 4).levelled_up
    assert practise(topic: Functions, level: 1, score: 5).levelled_up
    assert practise(topic: SimultaneousEquations, level: 1, score: 5).levelled_up
    assert_equal 2, @user.unlocked_level(Functions)

    Topic::ALL.each do |topic|
      assert_equal({ 3 => 20, 2 => 10, 1 => 5 }, topic.star_scores, topic.title)
    end
  end

  test "a level keeps its most stars, and more are new" do
    practise(level: 1, score: 6)
    silver = practise(level: 1, score: 12)
    worse = practise(level: 1, score: 8)
    gold = practise(level: 1, score: 21)

    assert_equal [ 2, nil, 3 ], [ silver.new_stars, worse.new_stars, gold.new_stars ]
    assert_not silver.levelled_up, "only the first bronze unlocks the next level"
    assert_equal 3, @user.stars(TimesTables, 1)
  end

  test "a daily challenge earns no stars and unlocks nothing" do
    challenge = practise(level: 1, score: 25, mode: "challenge")
    assert_equal 0, challenge.stars
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
    (1..4).each { |level| practise(level: level, score: 5) }
    assert_equal 5, @user.unlocked_level(TimesTables)
    assert_nil @user.next_level(TimesTables)
  end
end
