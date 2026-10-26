require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  test "embeds the questions so the test needs no requests while it runs" do
    sign_in_as users(:ada)
    get play_path("times-tables")

    assert_response :success
    sets = JSON.parse(css_select("[data-controller=test]").first["data-test-question-sets-value"])
    assert_equal 1 + User::Practisable::SPARE_QUESTION_SETS, sets.size, "spares for playing offline"
    assert_equal sets.size, sets.map { _1["id"] }.uniq.size
    assert_equal User::Practisable::QUESTION_COUNT, sets.first["questions"].size
    question = sets.first["questions"].first
    assert_equal %w[a b text answer], question.keys
    assert_select "meta[name=viewport][content*='maximum-scale=1']"
    assert_select "a.logo", count: 0, message: "nothing to tap away to mid-test"
    assert_select ".site-footer", count: 0
  end

  test "the timer has one hand, starting at 12" do
    get play_path("times-tables")
    assert_select ".timer__clock .clock__hand", 1
    assert_select ".timer__clock .clock__hand[data-test-target=hand]:not([transform])"
  end
end
