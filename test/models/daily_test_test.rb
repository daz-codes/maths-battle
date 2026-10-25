require "test_helper"

class DailyTestTest < ActiveSupport::TestCase
  setup do
    @ada, @bob = users(:ada), users(:bob)
    @day = Date.new(2026, 11, 3)
  end

  def play(user, right:, day: @day, ms: 1000, **options)
    travel_to(ActiveSupport::TimeZone["London"].local(day.year, day.month, day.day, 12)) do
      Attempt.record!(user: user, topic: "times_tables", level: 2, mode: "daily", day: day.iso8601,
        results: Array.new(right) { { a: 2, b: 3, given: 6, ms: ms } }, **options)
    end
  end

  test "the same questions for everyone on a day, the classic tables, and new ones the next day" do
    test = DailyTest.new(@day)
    assert_equal test.questions, DailyTest.new(@day).questions
    assert_not_equal test.questions, DailyTest.new(@day + 1).questions
    assert_equal User::QUESTION_COUNT, test.questions.size
    assert test.questions.all? { |question| question[:text].match?(/\A\d+ × \d+\z/) }
    assert_equal 1, DailyTest.new(DailyTest::FIRST_DAY).number
    assert_equal 10, DailyTest.new(DailyTest::FIRST_DAY + 9).number
  end

  test "anyone can play it, whatever level they've reached, once a day, on the day it was for" do
    assert_equal 1, @ada.unlocked_level(TimesTables)
    game = play(@ada, right: 5)
    assert game.daily_test?
    assert_equal game, @ada.daily_test_on(@day)

    assert_raises(Attempt::Invalid) { play(@ada, right: 9) }
    assert_raises(Attempt::Invalid, "yesterday's questions can't be played today") { play(@bob, right: 9, day: @day - 1, played_at: Time.current.iso8601) }
    assert_raises(Attempt::Invalid) do
      Attempt.record!(user: @bob, topic: "times_tables", level: 1, mode: "daily", day: Date.current.iso8601, results: [ { a: 2, b: 3, given: 6, ms: 1000 } ])
    end
    assert play(@ada, right: 5, day: @day + 1), "tomorrow's is new"
  end

  test "it doesn't change a level's best or give level awards, but keeps the streak going" do
    game = play(@ada, right: 12)
    assert_not game.new_high_score
    assert_not @ada.badges.exists?(kind: "level_2_times_tables"), "playing at level 2 isn't reaching it"
    assert_equal 0, @ada.best_score(TimesTables, 2)
    assert_equal 1, @ada.reload.current_streak
  end

  test "each game stands among the day's: its place, the players, and the top percentage it's in" do
    carol, dan = %w[ carol dan ].map { User.create!(username: _1, password: "a long password 123") }
    top = play(@ada, right: 20)
    play(@bob, right: 10)
    play(carol, right: 10)
    last = play(dan, right: 2)
    play(@ada, right: 30, day: @day + 1)

    test = DailyTest.new(@day)
    assert_equal 4, test.players, "another day's game doesn't count"
    assert_equal DailyTest::Standing.new(rank: 1, players: 4, top_percent: 25, beaten_percent: 75), test.standing_of(top)
    assert_equal [ 2, 50 ], test.standing_of(@bob.daily_test_on(@day)).then { [ _1.rank, _1.top_percent ] }
    assert_equal [ 2, 50 ], test.standing_of(carol.daily_test_on(@day)).then { [ _1.rank, _1.top_percent ] }, "a tie shares the place"
    assert_equal [ 4, 100, 0 ], test.standing_of(last).then { [ _1.rank, _1.top_percent, _1.beaten_percent ] }
  end
end
