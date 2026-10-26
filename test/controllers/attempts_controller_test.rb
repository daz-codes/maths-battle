require "test_helper"

class AttemptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:ada)
    sign_in_as @user
  end

  test "saves an attempt and returns the results page" do
    unlock(@user, TimesTables, 2)

    assert_difference -> { @user.attempts.count } do
      post attempts_path, params: game_upload(topic: "times_tables", level: 2, results: answers([ 7, 8, 56 ], [ 6, 7, 41 ])), as: :json
    end

    assert_response :created
    attempt = @user.attempts.last
    assert_equal attempt_path(attempt), response.parsed_body["url"]
    assert_equal 1, attempt.correct
  end

  test "an offline game uploaded again isn't saved twice" do
    upload = game_upload(results: answers(*right_answers(5)), client_id: "f6b1", played_at: 1.hour.ago.iso8601)

    assert_difference -> { Attempt.count } => 1 do
      post attempts_path, params: upload, as: :json
      post attempts_path, params: upload, as: :json
    end
    assert_response :created
  end

  test "the device's time zone decides which day a game counts for" do
    travel_to Time.utc(2026, 10, 16, 2, 30) do
      post attempts_path, params: game_upload(time_zone: "America/New_York", results: answers(*right_answers(5))), as: :json
    end

    assert_equal "America/New_York", @user.reload.time_zone
    assert_equal Date.new(2026, 10, 15), @user.attempts.last.played_on, "half past ten at night on the 15th in New York"
  end

  test "an unknown time zone from the device is ignored" do
    post attempts_path, params: game_upload(time_zone: "Mars/Olympus_Mons", results: answers(*right_answers(5))), as: :json

    assert_response :created
    assert_equal "London", @user.reload.time_zone
  end

  test "saves an equations game, checking the answers itself" do
    unlock(@user, Equations, 5)
    results = [ { type: "ax=b", a: 12, b: 9, v: "x", flip: false, given: "3/4", ms: 2000 },
                { type: "a(x+b)=c", a: 4, b: 2, c: 30, v: "t", flip: true, given: "6", ms: 3000 } ]

    post attempts_path, params: game_upload(topic: "equations", level: 5, results: results), as: :json

    assert_response :created
    attempt = @user.attempts.last
    assert_equal [ "equations", 1, 2 ], [ attempt.topic, attempt.correct, attempt.answered ]
    assert_equal [ true, false ], attempt.results.map { _1["correct"] }
  end

  test "rejects a made-up attempt" do
    assert_no_difference -> { Attempt.count } do
      post attempts_path, params: game_upload(results: answers(*Array.new(151) { [ 2, 2, 4 ] }, ms: 10)), as: :json
    end
    assert_response :unprocessable_entity
  end

  test "rejects results that aren't a list" do
    numbered = { "0" => { a: 2, b: 3, given: "6", ms: 900 } }

    assert_no_difference -> { Attempt.count } do
      post attempts_path, params: game_upload(results: numbered), as: :json
    end
    assert_response :unprocessable_entity
    assert_equal "Results must be a list", response.parsed_body["error"]
  end

  test "results page shows the score and where it came from, with no gems or bonuses" do
    attempt = Attempt.record!(user: @user, results: answers(*right_answers(5), ms: 500) + answers([ 2, 3, 7 ]))

    get attempt_path(attempt)
    assert_select ".card__number", text: "175"
    assert_select ".result__score", text: /175\s+5 correct answers/
    assert_select ".score-tally__right", text: "Right answers +50"
    assert_select ".score-tally__speed", text: "Speed +100"
    assert_select ".score-tally__combo", text: "Combos (best run 5) +30"
    assert_select ".score-tally__wrong", text: "Wrong answers −5"
    assert_select ".icon--gem", count: 0
    assert_select ".gems-earned", count: 0
  end

  test "results page never mentions streak freezes, even for a game that earned one before they were put away" do
    attempt = Attempt.record!(user: @user, results: answers(*right_answers(5)))
    attempt.update_columns(earned_streak_freeze: true, streak: 7)

    get attempt_path(attempt)
    assert_select ".freeze-earned", count: 0
    assert_no_match(/freeze/i, response.body.gsub(/<[^>]+>/, ""))
  end

  test "results go back to where the game was played from: Practice, to change level or topic" do
    get attempt_path(record_tables_game(@user, answers([ 7, 8, 56 ])))
    assert_select "a.back-link[href=?]", practice_path, text: "← Practice"

    daily = Attempt.record!(user: @user, topic: "times_tables", level: 2, mode: "daily", day: @user.today.iso8601, results: answers([ 7, 8, 56 ]))
    get attempt_path(daily)
    assert_select "a.back-link[href=?]", challenge_path, text: "← Daily Challenge"
  end

  test "results page shows the score, feedback and missed facts" do
    attempt = record_tables_game(@user, answers([ 7, 8, 54 ], [ 6, 7, 42 ], [ 3, 3, 9 ]))

    get attempt_path(attempt)
    assert_response :success
    assert_select ".card__number", text: attempt.score.to_s
    assert_select ".result__score", text: /2\s+correct answers/
    assert_select ".banner", text: /New high score/
    assert_select ".feedback", text: /Practise your/
    assert_select ".missed li", text: "7 × 8 = 56"
    assert_select ".missed__slow", count: 0
    assert_select "a[href=?]", stats_path("times-tables"), text: "See your stats"
    assert_select ".results__actions > a.button--blue[href=?]", play_path("times-tables", level: 2), text: "Play again"
    assert_select ".results__actions > button.button--share", text: "Share"
    assert_select "[data-controller=share][data-share-text-value*=?]", share_url(attempt.share_token)
    assert_select "header a.logo[href=?]", root_path
    assert_select "a.button", text: "Home", count: 0
  end

  test "can't see someone else's results" do
    attempt = Attempt.record!(user: users(:bob), results: answers([ 2, 2, 4 ]))

    get attempt_path(attempt)
    assert_response :not_found
  end
end
