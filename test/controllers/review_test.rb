require "test_helper"

class ReviewTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:ada)
    sign_in_as @user
  end

  def review_upload(score:)
    get play_path("times-tables", review: 1)
    set = JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"]).first
    results = set["questions"].first(score).map { |question| question.slice("a", "b").merge("given" => question["answer"], "ms" => 1000) }
    { attempt: { topic: "times_tables", level: 1, client_id: set["id"], ticket: set["ticket"], results: results } }
  end

  test "Practice offers a review only when there's something to review" do
    get practice_path
    assert_select "a.button--review", count: 0

    Attempt.record!(user: @user, results: answers([ 3, 5, 14 ], [ 2, 5, 11 ], [ 2, 3, 6 ]))
    get practice_path
    assert_select "a.button--review[href=?]", play_path("times-tables", review: 1), text: "Review mistakes (2)"
  end

  test "a review game is made of those questions only" do
    Attempt.record!(user: @user, results: answers([ 3, 5, 14 ], [ 2, 5, 11 ]))
    get play_path("times-tables", review: 1)

    assert_select "[data-test-mode-value=review]"
    questions = JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"]).first["questions"]
    assert_equal [ "2 × 5", "3 × 5" ], questions.map { _1["text"] }.sort, "each once"
    assert_select ".test__bar [data-test-target=progress]", text: "1/2"
    assert_select "[data-test-target=seconds]", count: 0, message: "no clock"
  end

  test "an incomplete review cannot be saved or earn stars, even with a different requested mode" do
    Attempt.record!(user: @user, results: answers([ 3, 5, 14 ], [ 2, 5, 11 ]))
    upload = review_upload(score: 2)
    upload[:attempt][:mode] = "practice"
    complete_results = upload[:attempt][:results]

    [ [], complete_results.first(1), complete_results.first(1).map { _1.merge("given" => "1") } ].each do |partial_results|
      upload[:attempt][:results] = partial_results
      assert_no_difference -> { @user.attempts.count } do
        assert_no_changes -> { @user.reload.gems } do
          post attempts_path, params: upload, as: :json
        end
      end
      assert_response :unprocessable_entity
      assert_equal "Answer every question to finish the review", response.parsed_body["error"]
    end

    upload[:attempt][:results] = complete_results
    post attempts_path, params: upload, as: :json
    assert_response :created
    assert @user.attempts.last.review?
    assert_equal 50, @user.attempts.last.gems
  end

  test "a complete review earns its bonus even with wrong answers, and a retry earns nothing extra" do
    Attempt.record!(user: @user, results: answers([ 3, 5, 14 ], [ 2, 5, 11 ]))
    upload = review_upload(score: 2)
    upload[:attempt][:results].each { _1["given"] = "1" }

    assert_difference -> { @user.reload.gems }, 50 do
      post attempts_path, params: upload, as: :json
    end
    assert_response :created
    url = response.parsed_body["url"]
    assert_equal 0, @user.attempts.last.score

    assert_no_difference -> { @user.attempts.count } do
      assert_no_changes -> { @user.reload.gems } do
        post attempts_path, params: upload, as: :json
      end
    end
    assert_response :created
    assert_equal url, response.parsed_body["url"]
  end

  test "it's saved as a review: no stars, no level up, no high score to beat" do
    Attempt.record!(user: @user, results: answers([ 3, 5, 14 ], [ 2, 5, 11 ]))
    post attempts_path, params: review_upload(score: 12), as: :json
    assert_response :created

    review = @user.attempts.last
    assert review.review?
    assert_equal 0, review.stars
    assert_not review.levelled_up
    assert_not review.new_high_score
    assert_equal 1, @user.unlocked_level(TimesTables), "12 would be a bronze in practice"
  end

  test "its results page says how many were right, with no clock, best or sharing, then on to what's left" do
    Attempt.record!(user: @user, results: answers([ 3, 5, 14 ], [ 2, 5, 11 ]))
    upload = review_upload(score: 2)
    upload[:attempt][:results].last["given"] = "1"
    post attempts_path, params: upload, as: :json
    get response.parsed_body["url"]

    assert_select ".label", text: /Times tables, review/
    assert_select ".result__score", text: "1 of 2 right"
    assert_select ".result__stats", text: /Best/, count: 0
    assert_select ".score-tally", count: 0, message: "a review has no score, just how many were right"
    assert_select ".button--share", count: 0
    assert_select ".results__actions a[href=?]", play_path("times-tables", review: 1), text: "Review 1 more"
    assert_select ".level-progress", count: 0
  end

  test "once every mistake is put right, it's back to practice" do
    Attempt.record!(user: @user, results: answers([ 3, 5, 14 ]))
    post attempts_path, params: review_upload(score: 1), as: :json
    get response.parsed_body["url"]

    assert_select ".feedback", text: /Every one right! Those mistakes are fixed/
    assert_select ".results__actions a[href=?]", play_path("times-tables", level: 1), text: "Play level 1"
  end

  test "nothing to review goes back home" do
    get play_path("times-tables", review: 1)
    assert_redirected_to root_path
  end

  test "a signed review still saves after another game unlocks a level" do
    Attempt.record!(user: @user, results: answers([ 3, 5, 14 ]))
    upload = review_upload(score: 3)
    unlock(@user, TimesTables, 2)

    post attempts_path, params: upload, as: :json
    assert_response :created
    assert @user.attempts.last.review?
    assert_equal 1, @user.attempts.last.level
  end
end
