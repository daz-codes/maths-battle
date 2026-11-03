require "test_helper"

class DailyTestTest < ActiveSupport::TestCase
  setup do
    @ada, @bob = users(:ada), users(:bob)
    @day = Date.new(2026, 11, 3)
  end

  def noon(day = @day) = ActiveSupport::TimeZone["London"].local(day.year, day.month, day.day, 12)

  def play(user, right:, day: @day, on: @day, ms: 1000)
    travel_to(noon(on)) do
      Attempt.record!(user: user, topic: "times_tables", level: 2, mode: "daily", day: day.iso8601,
        results: Array.new(right) { { a: 2, b: 3, given: 6, ms: ms } })
    end
  end

  def fact_of(question) = TimesTables.fact_key(question.stringify_keys)

  test "new questions every game, the classic tables, a full set, and numbered from the first day" do
    test = DailyTest.new(@day)
    assert_not_equal test.questions.map { _1[:text] }, test.questions.map { _1[:text] }, "a new set every game"
    assert_equal User::QUESTION_COUNT, test.questions.size
    assert test.questions.all? { |question| question[:text].match?(/\A\d+ × \d+\z/) }
    assert_equal 1, DailyTest.new(DailyTest::KINDS["tables"][:first_day]).number
    assert_equal 10, DailyTest.new(DailyTest::KINDS["tables"][:first_day] + 9).number
  end

  test "every set is as hard as any other: a question from each third of the facts, easy to hard, in turn" do
    balancer = DailyTest::Balancer.new(TimesTables, 2, day: @day)
    easy, medium, hard = balancer.tiers
    assert_equal TimesTables.facts(2).sort, (easy + medium + hard).sort
    assert_in_delta easy.size, hard.size, 1

    [ Random.new(1), Random.new(2) ].each do |random|
      questions = balancer.questions(count: 30, random: random)
      questions.each_slice(3) do |three|
        assert_equal [ 0, 1, 2 ], three.map { |question| balancer.tiers.index { fact_of(question).in?(_1) } }.sort, "one of each in every three"
      end
      assert questions.each_cons(2).none? { |a, b| fact_of(a) == fact_of(b) }, "never the same fact twice running"
    end
  end

  test "the tiers come from how hard everyone finds each fact, leaning on the topic's own idea until there's enough" do
    expected = DailyTest::Balancer.new(TimesTables, 2, day: @day)
    assert_includes expected.tiers.first, "2x2", "with no answers yet, the topic says the 2 times table is easy"
    assert_includes expected.tiers.last, "7x8", "and 7 × 8 is hard"

    # Lots of players get 2 × 2 wrong, and 7 × 8 right, quickly
    [ @ada, @bob ].each do |user|
      FactStat.create!(user: user, topic: "times_tables", level: 2, fact: "2x2", correct_count: 20, wrong_count: 80, correct_ms: 20 * 4000)
      FactStat.create!(user: user, topic: "times_tables", level: 2, fact: "7x8", correct_count: 100, wrong_count: 0, correct_ms: 100 * 900)
    end
    learnt = DailyTest::Balancer.new(TimesTables, 2, day: @day)
    assert_includes learnt.tiers.last, "2x2"
    assert_includes learnt.tiers.first, "7x8"
    assert_operator learnt.hardness("2x2"), :>, learnt.hardness("7x8")

    FactStat.create!(user: @ada, topic: "times_tables", level: 3, fact: "3x4", correct_count: 0, wrong_count: 500)
    assert_equal learnt.tiers, DailyTest::Balancer.new(TimesTables, 2, day: @day).tiers, "only answers at the challenge's level count"
  end

  test "anyone can play it, whatever level they've reached, as often as they like, but only on the day it was for" do
    assert_equal 1, @ada.unlocked_level(TimesTables)
    first = play(@ada, right: 5)
    assert first.daily_test?
    better = play(@ada, right: 9)
    play(@ada, right: 2)
    test = DailyTest.new(@day)
    assert_equal better, @ada.daily_game(test), "their best today"
    assert_equal 3, @ada.daily_games_on(test).count

    assert_raises(Attempt::Invalid, "yesterday's questions can't be played today") { play(@bob, right: 9, day: @day - 1) }
    assert_raises(Attempt::Invalid, "only at the challenge's level") do
      Attempt.record!(user: @bob, topic: "times_tables", level: 1, mode: "daily", day: Date.current.iso8601, results: [ { a: 2, b: 3, given: 6, ms: 1000 } ])
    end
    assert play(@ada, right: 5, day: @day + 1, on: @day + 1), "tomorrow's is new"
  end

  test "Patternz is retired: it isn't offered or saved any more, but its old games still show" do
    assert_equal [ "tables" ], DailyTest.on(@day).map(&:kind)
    assert DailyTest.new(@day, "patternz").retired?
    assert_raises(Attempt::Invalid) do
      Attempt.record!(user: @ada, topic: "sequences", level: Sequences.max_level, mode: "daily", day: Date.current.iso8601, results: [])
    end

    old = @ada.attempts.create!(topic: "sequences", level: Sequences.max_level, mode: "daily", results: [], played_at: Time.current)
    assert_equal "Patternz", old.daily_test.name
  end

  test "it doesn't change a level's best or give level awards, but keeps the streak going" do
    game = play(@ada, right: 12)
    assert_not game.new_high_score
    assert_not @ada.badges.exists?(kind: "level_2_times_tables"), "playing at level 2 isn't reaching it"
    assert_equal 0, @ada.best_score(TimesTables, 2)
    assert_equal 1, @ada.reload.current_streak
  end

  test "each player's best game stands among everyone else's best: its place, the players, and the top percentage" do
    carol, dan = %w[ carol dan ].map { User.create!(username: _1, password: "a long password 123") }
    play(@ada, right: 4)
    top = play(@ada, right: 20)
    play(@bob, right: 10)
    play(@bob, right: 1)
    play(carol, right: 10)
    last = play(dan, right: 2)
    play(@ada, right: 30, day: @day + 1, on: @day + 1)

    test = DailyTest.new(@day)
    assert_equal 4, test.players, "each player once, however many games, and not another day's"
    assert_equal DailyTest::Standing.new(rank: 1, players: 4, top_percent: 25, beaten_percent: 75), test.standing_of(top)
    assert_equal [ 2, 50 ], test.standing_of(@bob.daily_game(test)).then { [ _1.rank, _1.top_percent ] }
    assert_equal [ 2, 50 ], test.standing_of(carol.daily_game(test)).then { [ _1.rank, _1.top_percent ] }, "a tie shares the place"
    assert_equal [ 4, 100, 0 ], test.standing_of(last).then { [ _1.rank, _1.top_percent, _1.beaten_percent ] }
  end
end
