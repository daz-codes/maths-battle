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
