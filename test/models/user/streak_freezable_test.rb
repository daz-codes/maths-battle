require "test_helper"

class User::StreakFreezableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  def day(number) = Date.new(2026, 10, number)

  def play_on(date, **options)
    travel_to(date.in_time_zone.change(hour: 12)) { Attempt.record!(user: @user, results: answers(*right_answers(5)), **options) }
  end

  def on(date, &) = travel_to(date.in_time_zone.change(hour: 12), &)

  test "a freeze costs 10,000 stars, and two is the most you can hold" do
    @user.attempts.create!(topic: "times_tables", results: []).update_column(:stars, 30_500)

    @user.buy_streak_freeze!
    assert_equal [ 1, 20_500 ], [ @user.streak_freezes, @user.stars ]
    @user.buy_streak_freeze!
    assert_equal [ 2, 10_500 ], [ @user.streak_freezes, @user.stars ]
    assert_raises(User::StreakFreezable::NotAllowed) { @user.buy_streak_freeze! }
  end

  test "can't buy one without enough stars" do
    assert_raises(User::StreakFreezable::NotAllowed) { @user.buy_streak_freeze! }
    assert_equal 0, @user.reload.streak_freezes
  end

  test "a free freeze when the streak reaches 7 days, and again at 30" do
    games = (1..7).map { |number| play_on(day(number)) }
    assert games.last.earned_streak_freeze
    assert games.first(6).none?(&:earned_streak_freeze)
    assert_equal 1, @user.reload.streak_freezes

    assert_not play_on(day(7)).earned_streak_freeze, "a second game the same day doesn't earn another"
    (8..30).each { |number| play_on(day(number)) }
    assert_equal 2, @user.reload.streak_freezes
  end

  test "no free freeze when already holding the most" do
    @user.update!(streak_freezes: 2)
    games = (1..7).map { |number| play_on(day(number)) }
    assert_not games.last.earned_streak_freeze
    assert_equal 2, @user.reload.streak_freezes
  end

  test "a missed day is covered by a freeze: the streak goes on, without counting that day" do
    (1..3).each { |number| play_on(day(number)) }
    @user.update!(streak_freezes: 1)

    on(day(5)) do
      assert_equal 1, @user.use_streak_freezes!
      assert_equal 3, @user.streak, "the 4th was frozen, not practised"
      assert @user.streak_at_risk?
    end
    assert_equal 0, @user.reload.streak_freezes
    assert_equal [ day(4) ], @user.frozen_days.pluck(:day)

    play_on(day(5))
    assert_equal 4, @user.reload.current_streak
    on(day(5)) { assert_equal 4, @user.streak }
  end

  test "nothing is used when there aren't enough freezes to save the streak" do
    (1..3).each { |number| play_on(day(number)) }
    @user.update!(streak_freezes: 1)

    on(day(6)) do
      assert_equal 0, @user.use_streak_freezes!
      assert_equal 0, @user.streak
    end
    assert_equal 1, @user.reload.streak_freezes
  end

  test "two missed days can be covered by two freezes" do
    (1..3).each { |number| play_on(day(number)) }
    @user.update!(streak_freezes: 2)

    on(day(6)) { assert_equal 2, @user.use_streak_freezes! }
    play_on(day(6))
    assert_equal 4, @user.reload.current_streak
  end

  test "nothing to cover while the streak is still alive, or when there's no streak" do
    @user.update!(streak_freezes: 2)
    on(day(5)) { assert_equal 0, @user.use_streak_freezes! }

    play_on(day(4))
    on(day(5)) { assert_equal 0, @user.use_streak_freezes!, "yesterday was played, so nothing's missed" }
  end

  test "a game played offline on a frozen day gives the freeze back" do
    (1..3).each { |number| play_on(day(number)) }
    @user.update!(streak_freezes: 1)
    on(day(5)) { @user.use_streak_freezes! }

    on(day(5)) { Attempt.record!(user: @user, results: answers(*right_answers(5)), played_at: day(4).in_time_zone.change(hour: 18).iso8601) }
    assert_equal 1, @user.reload.streak_freezes
    assert_empty @user.frozen_days
    assert_equal 4, @user.current_streak
  end
end
