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

  test "the Challenge is today's test: play it once, then see where it stands among everyone today" do
    3.times { |i| Attempt.record!(user: User.create!(username: "player#{i}", password: "a long password 123"), topic: "times_tables", level: 2, mode: "daily",
      day: Date.current.iso8601, results: Array.new(2 + i) { { a: 2, b: 3, given: 6, ms: 3000 } }) }

    get root_path
    assert_select ".home-action--challenge .ui-daily__edition", text: /Daily Tables Test · Patternz/
    get challenge_path
    assert_select "h1", text: /Daily Challenge/
    assert_select "details.daily-test:not([open]) summary .daily-test__name", text: /Daily Tables Test #\d+/, message: "a button to open each"
    assert_select "details.daily-test summary .daily-test__name", text: /Patternz #\d+/
    assert_select ".daily-test__status", text: "Not played yet", count: 2
    assert_select ".stats", count: 0, message: "no stats before a first game"
    assert_select "button.button--share", count: 0
    assert_select "a.button[href=?]", play_path("times-tables", daily: "tables"), text: "Play"
    assert_select "a.button[href=?]", play_path("sequences", daily: "patternz"), text: "Play"
    assert_select ".daily-test--tables .aside", text: "3 players so far today"

    get play_path("times-tables", daily: "tables")
    assert_select "[data-test-mode-value=daily][data-test-level-value='2']"
    set = JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"]).first
    assert_equal DailyTest.new(@ada.today, "tables").questions.map { _1[:text] }, set["questions"].map { _1["text"] }, "everyone's are the same"

    game = play_today(right: 8)
    assert_equal [ "daily", 2 ], [ game.mode, game.level ]
    get attempt_path(game)
    assert_select ".banner--group", text: "Top score today!"
    assert_select ".label", text: /Daily Tables Test #\d+/
    assert_select ".result__stats", text: /Best/, count: 0
    assert_select "a.button[href=?]", challenge_path, text: "See today's results"
    assert_select "[data-share-text-value*=?]", "🎯 Top 25% today"

    get challenge_path
    assert_select ".daily-test--tables summary .daily-test__status", text: "Done · Top score today!", message: "what's inside, while it's closed"
    assert_select ".daily-test--tables .daily-standing .card__number", text: game.score.to_s
    assert_select ".daily-test--tables .daily-standing .aside", text: "1st of 4 players so far today"
    assert_select ".daily-test--tables a.button", text: "Play", count: 0
    assert_select ".daily-test--patternz a.button", text: "Play", message: "the other's still to play"
    assert_select ".daily-test--tables button.button--share[data-share-text-value*=?]", "🎯 Top 25% today", text: "Share", message: "always there once it's played"
    assert_match /Best score\s+#{game.score}/, css_select(".stats div").map { _1.text.squish }.join(" · ")
    assert_match /Played\s*1/, css_select(".stats div").map { _1.text.squish }.join(" · ")
    get root_path
    assert_select ".home-action--challenge .ui-daily__edition", text: /1 of 2 done today/

    get play_path("times-tables", daily: "tables")
    assert_redirected_to challenge_path, "one go a day"
    get play_path("times-tables", daily: 1)
    assert_redirected_to challenge_path, "a link from before Patternz is the Daily Tables Test"
  end

  test "stats from every Daily Tables Test played: the best, the average, and how many" do
    scores = [ 3, 9 ].map.with_index do |right, ago|
      Attempt.record!(user: @ada, topic: "times_tables", level: 2, mode: "daily", day: (Date.current - ago - 1).iso8601,
        played_at: (Time.current - (ago + 1).days).iso8601, results: Array.new(right) { { a: 2, b: 3, given: 6, ms: 1000 } }).score
    end
    get challenge_path
    assert_match /Best score\s+#{scores.max}/, css_select(".stats div").map { _1.text.squish }.join(" · ")
    assert_match /Average score\s*#{(scores.sum / 2.0).round}/, css_select(".stats div").map { _1.text.squish }.join(" · ")
    assert_match /Played\s*2/, css_select(".stats div").map { _1.text.squish }.join(" · ")
    assert_select ".daily-test--tables a.button", text: "Play"
  end

  test "the top half hear their top percentage, then how many they beat, and last place that there's always tomorrow" do
    [ 20, 20, 1 ].each_with_index { |right, i| Attempt.record!(user: User.create!(username: "player#{i}", password: "a long password 123"), topic: "times_tables",
      level: 2, mode: "daily", day: Date.current.iso8601, results: Array.new(right) { { a: 2, b: 3, given: 6, ms: 500 } }) }
    get attempt_path(play_today(right: 3))
    assert_select ".banner--group", text: "You beat 25% of players today"

    helper = Object.new.extend(DailyChallengeHelper)
    assert_equal "You're in the top 10% today", helper.daily_standing_message(DailyTest::Standing.new(rank: 3, players: 30, top_percent: 10, beaten_percent: 90))
    assert_equal "Tomorrow's a new test!", helper.daily_standing_message(DailyTest::Standing.new(rank: 5, players: 5, top_percent: 100, beaten_percent: 0))
  end

  test "Patternz: today's mixed sequences, the same for everyone, one go, compared and shared separately" do
    get play_path("sequences", daily: "patternz")
    assert_select "[data-test-mode-value=daily][data-test-level-value='5']"
    set = JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"]).first
    texts = set["questions"].map { _1["text"] }
    assert_equal DailyTest.new(@ada.today, "patternz").questions.map { _1[:text] }, texts
    kinds = set["questions"].map { _1["type"] }.uniq
    assert_operator kinds.size, :>=, 6, "every kind of sequence mixed in"

    results = set["questions"].first(4).map { |question| question.except("text", "answer", "solution").merge("given" => question["answer"], "ms" => 2000) }
    post attempts_path, params: { attempt: { topic: "sequences", level: 5, client_id: set["id"], ticket: set["ticket"], results: results } }, as: :json
    assert_response :created
    game = @ada.attempts.last
    assert_equal [ "daily", "sequences", 4 ], [ game.mode, game.topic, game.correct ]
    assert_equal [ 5, 1 ], [ game.level, @ada.unlocked_level(Sequences) ], "every level, though Ada's only reached the first"

    get attempt_path(game)
    assert_select ".label", text: /Patternz #\d+/
    assert_select ".banner--group", text: "You're the first to play today!"
    get challenge_path
    assert_select ".daily-test--patternz .daily-standing .card__number", text: game.score.to_s
    assert_select ".daily-test--tables a.button", text: "Play"
    assert_match "Patternz #", css_select(".daily-test--patternz [data-share-text-value]").first["data-share-text-value"]

    get play_path("sequences", daily: "patternz")
    assert_redirected_to challenge_path
    get play_path("times-tables", daily: "patternz")
    assert_redirected_to challenge_path, "Patternz is sequences"
  end
end
