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

  test "the home page offers a review only when there's something to review" do
    get root_path
    assert_select "a.button--review", count: 0

    Attempt.record!(user: @user, results: answers([ 3, 5, 14 ], [ 2, 5, 11 ], [ 2, 3, 6 ]))
    get root_path
    assert_select "a.button--review[href=?]", play_path("times-tables", review: 1), text: "🔁 Review mistakes (2)"
  end

  test "a review game is made of those questions only" do
    Attempt.record!(user: @user, results: answers([ 3, 5, 14 ], [ 2, 5, 11 ]))
    get play_path("times-tables", review: 1)

    assert_select "[data-test-mode-value=review]"
    questions = JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"]).first["questions"]
    assert_equal [ "2 × 5", "3 × 5" ], questions.map { _1["text"] }.uniq.sort
  end

  test "it's saved as a review: no medal, no level up, no high score to beat" do
    Attempt.record!(user: @user, results: answers([ 3, 5, 14 ], [ 2, 5, 11 ]))
    post attempts_path, params: review_upload(score: 12), as: :json
    assert_response :created

    review = @user.attempts.last
    assert review.review?
    assert_nil review.medal
    assert_not review.levelled_up
    assert_not review.new_high_score
    assert_equal 1, @user.unlocked_level(TimesTables), "12 would be a bronze in practice"
  end

  test "its results page says it's a review, and offers another" do
    Attempt.record!(user: @user, results: answers([ 3, 5, 14 ]))
    post attempts_path, params: review_upload(score: 3), as: :json
    get response.parsed_body["url"]

    assert_select ".label", text: /Times tables, review/
    assert_select ".results__actions a[href=?]", play_path("times-tables", review: 1), text: "Review again"
    assert_select ".level-progress", count: 0
  end

  test "nothing to review goes back home" do
    get play_path("times-tables", review: 1)
    assert_redirected_to root_path
  end
end
