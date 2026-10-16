require "test_helper"

class AttemptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:ada)
    sign_in_as @user
  end

  test "saves an attempt and returns the results page" do
    assert_difference -> { @user.attempts.count } do
      post attempts_path, params: { attempt: { topic: "times_tables", results: answers([ 7, 8, 56 ], [ 6, 7, 41 ]) } }, as: :json
    end

    assert_response :created
    attempt = @user.attempts.last
    assert_equal attempt_path(attempt), response.parsed_body["url"]
    assert_equal 1, attempt.score
  end

  test "an offline game uploaded again isn't saved twice" do
    upload = { attempt: { results: answers(*right_answers(5)), client_id: "f6b1", played_at: 1.hour.ago.iso8601 } }

    assert_difference -> { Attempt.count } => 1 do
      post attempts_path, params: upload, as: :json
      post attempts_path, params: upload, as: :json
    end
    assert_response :created
  end

  test "saves an equations game, checking the answers itself" do
    results = [ { type: "ax=b", a: 12, b: 9, v: "x", flip: false, given: "3/4", ms: 2000 },
                { type: "a(x+b)=c", a: 4, b: 2, c: 30, v: "t", flip: true, given: "6", ms: 3000 } ]

    post attempts_path, params: { attempt: { topic: "equations", results: results } }, as: :json

    assert_response :created
    attempt = @user.attempts.last
    assert_equal [ "equations", 1, 2 ], [ attempt.topic, attempt.score, attempt.answered ]
    assert_equal [ true, false ], attempt.results.map { _1["correct"] }
  end

  test "rejects a made-up attempt" do
    assert_no_difference -> { Attempt.count } do
      post attempts_path, params: { attempt: { results: answers(*Array.new(151) { [ 2, 2, 4 ] }, ms: 10) } }, as: :json
    end
    assert_response :unprocessable_entity
  end

  test "results page shows the score, feedback and missed facts" do
    attempt = Attempt.record!(user: @user, results: answers([ 7, 8, 54 ], [ 6, 7, 42 ], [ 3, 3, 9 ]))

    get attempt_path(attempt)
    assert_response :success
    assert_select ".card__number", text: "2"
    assert_select ".banner", text: /New high score/
    assert_select ".feedback", text: /Practise your/
    assert_select ".missed li", text: "7 × 8 = 56"
    assert_select ".missed__slow", count: 0
    assert_select "a[href=?]", stats_path("times-tables"), text: "See your stats"
    assert_select "a.button--blue[href=?]", play_path("times-tables", level: 1), text: "Play again"
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
