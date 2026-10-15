require "test_helper"

class TimesTablesControllerTest < ActionDispatch::IntegrationTest
  test "embeds the questions so the test needs no requests while it runs" do
    sign_in_as users(:ada)
    get times_tables_path

    assert_response :success
    questions = JSON.parse(css_select("[data-controller=test]").first["data-test-questions-value"])
    assert_equal TimesTables::QuestionGenerator::COUNT, questions.size
    assert_equal %w[a b], questions.first.keys
    assert_select "meta[name=viewport][content*='maximum-scale=1']"
    assert_select "a.logo", count: 0, message: "nothing to tap away to mid-test"
    assert_select ".site-footer", count: 0
  end
end
