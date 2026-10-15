require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:ada) }

  test "visitors can start playing without signing up" do
    get root_path

    assert_response :success
    assert_select "a[href=?]", times_tables_path, text: "Start"
    assert_select ".streak__number", text: /0/
    assert_select "a[href=?]", new_registration_path
  end

  test "greets the player by name" do
    @user.update!(name: "Ada")
    sign_in_as @user

    get root_path
    assert_select ".greeting", text: "Hi Ada!"
  end

  test "shows the streak, best score and start button" do
    @user.update!(current_streak: 12, last_practised_on: @user.today, high_score: 41)
    sign_in_as @user

    get root_path
    assert_select ".streak__number", text: /12/
    assert_select ".stats", text: /41/
    assert_select "a[href=?]", times_tables_path, text: "Start"
    assert_select ".nudge", text: /Streak still going! You can keep playing to practise more/
  end

  test "says the streak has started on its first day" do
    @user.update!(current_streak: 1, last_practised_on: @user.today)
    sign_in_as @user

    get root_path
    assert_select ".nudge", text: /Streak started!/
  end

  test "warns when the streak is at risk" do
    @user.update!(current_streak: 3, last_practised_on: @user.today - 1)
    sign_in_as @user

    get root_path
    assert_select ".nudge--risk", text: /keep your streak/
  end
end
