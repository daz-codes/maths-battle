require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:ada) }

  test "sends signed out visitors to sign in" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "shows the streak, best score and start button" do
    @user.update!(current_streak: 12, last_practised_on: @user.today, high_score: 41)
    sign_in_as @user

    get root_path
    assert_select ".streak__number", text: /12/
    assert_select ".stats", text: /41/
    assert_select "a[href=?]", times_tables_path, text: "START"
    assert_select ".nudge", text: /Done for today/
  end

  test "warns when the streak is at risk" do
    @user.update!(current_streak: 3, last_practised_on: @user.today - 1)
    sign_in_as @user

    get root_path
    assert_select ".nudge--risk", text: /keep your streak/
  end
end
