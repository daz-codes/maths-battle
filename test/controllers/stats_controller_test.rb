require "test_helper"

class StatsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:ada) }

  test "shows each table's percentage and speed" do
    Attempt.record!(user: @user, results: [
      { a: 7, b: 8, given: 56, ms: 2000 }, { a: 7, b: 7, given: 48, ms: 1000 }, { a: 3, b: 4, given: 12, ms: 1000 }
    ])
    sign_in_as @user

    get stats_path
    assert_response :success
    assert_select "tbody tr", 12
    assert_select "thead th", text: "Accuracy"
    assert_select ".stats dt", text: "Accuracy"
    assert_select "tbody tr:nth-child(7) td", text: "50%" # 7×: 7×8 right, 7×7 wrong
    assert_select "tbody tr:nth-child(7) td", text: "2.0s"
    assert_select "tbody tr:nth-child(8) td", text: "100%"
    assert_select "tbody tr:nth-child(5) td", text: "—" # 5× not asked yet
    assert_select ".stats dd", text: "67%"
    assert_select ".stats dd", text: "1.5s"
    assert_select ".summary", count: 0, text: /best/, message: "no table has enough answers to rank yet"
  end

  test "visitors see an empty state" do
    get stats_path
    assert_response :success
    assert_select "table", count: 0
    assert_select ".aside", text: /Play a game/
  end
end
