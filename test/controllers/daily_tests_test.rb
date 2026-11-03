require "test_helper"

class DailyTestsTest < ActionDispatch::IntegrationTest
  setup do
    @ada = users(:ada)
    sign_in_as @ada
  end

  def play_today(right:)
    get play_path("times-tables", daily: "tables")
    set = JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"]).first
    results = set["questions"].first(right).map { |question| question.slice("a", "b").merge("given" => question["answer"], "ms" => 1000) }
    post attempts_path, params: { attempt: { topic: "times_tables", level: 2, client_id: set["id"], ticket: set["ticket"], results: results } }, as: :json
    assert_response :created
    @ada.attempts.last
  end

  def stats_text = css_select(".stats div").map { _1.text.squish }.join(" · ")

  test "the home page starts with today's challenge, then once it's played, the best today and Play again" do
    3.times { |i| Attempt.record!(user: User.create!(username: "player#{i}", password: "a long password 123"), topic: "times_tables", level: 2, mode: "daily",
      day: Date.current.iso8601, results: Array.new(2 + i) { { a: 2, b: 3, given: 6, ms: 3000 } }) }

    get root_path
    assert_select "main > section.ui-daily:first-of-type h2", text: "Daily Challenge", message: "first, before the other ways to play"
    assert_select ".ui-daily .ui-daily__game-name", text: /Tables Test\s*#\d+/
    assert_select ".ui-daily .ui-daily__game-name svg", 1, "with its topic's icon"
    assert_select ".ui-daily a.ui-daily__play[href=?][data-turbo-prefetch=false]", play_path("times-tables", daily: "tables"), text: /Play today's challenge/
    assert_select ".ui-daily .ui-daily__players", text: "3 players today"
    assert_select ".ui-daily", text: /Patternz/, count: 0
    assert_select "nav.ui-actions .home-action", 2, "practice and compete, after it"

    game = play_today(right: 8)
    get root_path
    assert_select ".ui-daily a.ui-daily__best[href=?]", attempt_path(game), text: /#{game.score}\s*Your best today · Top score today!/
    assert_select ".ui-daily a.ui-daily__play", text: /Play again/
  end

  test "play it again and again: new questions each time, the best today counting, and Play again on the result" do
    get challenge_path
    assert_select "h1", text: /Daily Challenge/
    assert_select "details.daily-test[open] summary .daily-test__name", text: /Tables Test #\d+/
    assert_select ".daily-test__status", text: "Not played yet today"
    assert_select ".daily-test", text: /Patternz/, count: 0
    assert_select ".stats", count: 0, message: "no stats before a first game"
    assert_select "a.button[href=?]", play_path("times-tables", daily: "tables"), text: "Play"
    assert_select ".aside", text: /new questions every game, all just as hard/

    get play_path("times-tables", daily: "tables")
    assert_select "[data-test-mode-value=daily][data-test-level-value='2']"
    first_set = JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"]).first["questions"].map { _1["text"] }
    get play_path("times-tables", daily: "tables")
    assert_not_equal first_set, JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"]).first["questions"].map { _1["text"] }

    first = play_today(right: 8)
    assert_equal [ "daily", 2 ], [ first.mode, first.level ]
    get attempt_path(first)
    assert_select ".banner--group", text: "You're the first to play today!"
    assert_select ".label", text: /Tables Test #\d+/
    assert_select "a.button--start[href=?]", play_path("times-tables", daily: "tables"), text: "Play again"
    assert_select "a.button[href=?]", challenge_path, text: "See today's results"

    worse = play_today(right: 3)
    get attempt_path(worse)
    assert_select ".best-line", text: /more to beat your best of #{first.score}/
    get challenge_path
    assert_select ".daily-test--tables summary .daily-test__score", text: /#{first.score}\s+your best today/
    assert_select ".daily-test--tables .daily-standing .card__number", text: first.score.to_s
    assert_select ".daily-test--tables .daily-standing .aside", text: "1st of 1 player so far today · best of 2 games"
    assert_select ".daily-test--tables a.button", text: "Play again"
    assert_select ".daily-test--tables button.button--share", text: "Share your best"
    assert_match /Played\s*2/, stats_text

    get play_path("times-tables", daily: 1)
    assert_response :success, "a link from before there were kinds is the Tables Test"
  end

  test "the result says how it compares with your best Tables Test, and the most you've got right in one" do
    first = play_today(right: 3)
    get attempt_path(first)
    assert_select ".best-line", count: 0, message: "nothing to compare with on a first go"

    travel 1.day do
      Attempt.record!(user: @ada, topic: "times_tables", level: 1, mode: "practice", results: Array.new(20) { { a: 2, b: 3, given: 6, ms: 500 } })
      attempt = play_today(right: 5)
      get attempt_path(attempt)
      assert_select ".best-line--new", text: "#{attempt.score}, up from #{first.score}", message: "not practice's best"
      assert_select ".best-line--right", text: "5 correct answers, your most yet!"
    end

    travel 2.days do
      get attempt_path(play_today(right: 4))
      assert_select ".best-line", text: /more to beat your best of/
      assert_select ".best-line--right", text: /4 correct answers · your most is 5/
    end
  end

  test "the result charts the week's Tables Tests, a column a day with each day's best, this game's highlighted" do
    get attempt_path(play_today(right: 3))
    assert_select ".week-chart", count: 0, message: "nothing to chart on a first go"

    travel 2.days do
      best = play_today(right: 6)
      attempt = play_today(right: 2)
      get attempt_path(attempt)
      assert_select ".week-chart__title", text: "Your Tables Test this week"
      assert_select ".week-chart__day", 7
      assert_select ".week-chart__day--missed", 5
      assert_select ".week-chart__day--this[aria-label=?]", "#{Date.current.strftime("%A %-d %B")}: #{attempt.score}, 2 right", message: "this game stands for today"
      assert_select ".week-chart__day--this .week-chart__label", text: "Today"

      get attempt_path(best)
      assert_select ".week-chart__day--this .week-chart__bar[style=?]", "--share: 1.0"
    end
  end

  test "stats from every Tables Test played: the best, the average, and how many" do
    scores = [ 3, 9 ].map.with_index do |right, ago|
      Attempt.record!(user: @ada, topic: "times_tables", level: 2, mode: "daily", day: (Date.current - ago - 1).iso8601,
        played_at: (Time.current - (ago + 1).days).iso8601, results: Array.new(right) { { a: 2, b: 3, given: 6, ms: 1000 } }).score
    end
    get challenge_path
    assert_match /Best score\s+#{scores.max}/, stats_text
    assert_match /Average score\s*#{(scores.sum / 2.0).round}/, stats_text
    assert_match /Played\s*2/, stats_text
    assert_select ".daily-test--tables a.button", text: "Play"
  end

  test "the top half hear their top percentage, then how many they beat, and last place to have another go" do
    [ 20, 20, 1 ].each_with_index { |right, i| Attempt.record!(user: User.create!(username: "player#{i}", password: "a long password 123"), topic: "times_tables",
      level: 2, mode: "daily", day: Date.current.iso8601, results: Array.new(right) { { a: 2, b: 3, given: 6, ms: 500 } }) }
    get attempt_path(play_today(right: 3))
    assert_select ".banner--group", text: "You beat 25% of players today"

    helper = Object.new.extend(DailyChallengeHelper)
    assert_equal "You're in the top 10% today", helper.daily_standing_message(DailyTest::Standing.new(rank: 3, players: 30, top_percent: 10, beaten_percent: 90))
    assert_equal "Have another go to climb the table!", helper.daily_standing_message(DailyTest::Standing.new(rank: 5, players: 5, top_percent: 100, beaten_percent: 0))
  end

  test "Patternz is retired: its link goes to the Daily Challenge, and an old game still shows without Play again" do
    get play_path("sequences", daily: "patternz")
    assert_redirected_to challenge_path
    get play_path("times-tables", daily: "patternz")
    assert_redirected_to challenge_path

    old = @ada.attempts.create!(topic: "sequences", level: Sequences.max_level, mode: "daily", results: [], played_at: 1.day.ago)
    get attempt_path(old)
    assert_response :success
    assert_select ".label", text: /Patternz #\d+/
    assert_select "a", text: "Play again", count: 0
  end
end
