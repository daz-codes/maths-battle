require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:ada) }

  test "visitors can start playing without signing up" do
    get root_path

    assert_response :success
    assert_select ".site-header .tagline", text: "Improve your maths in a minute every day"
    assert_select "a[href=?]", times_tables_path, text: "Play"
    assert_select ".streak__number", text: /0/
    assert_select ".nudge", text: "Click play to start your streak"
    assert_select "a[href=?]", new_registration_path
  end

  test "greets the player by name" do
    @user.update!(name: "Ada")
    sign_in_as @user

    get root_path
    assert_select ".greeting", text: /Hi Ada!/
  end

  test "shows the streak, best score and start button" do
    @user.update!(current_streak: 12, last_practised_on: @user.today, high_score: 41)
    sign_in_as @user

    get root_path
    assert_select ".streak__number", text: /12/
    assert_select ".stats", text: /41/
    assert_select "a[href=?]", stats_path, text: "See all stats"
    assert_select "a[href=?]", times_tables_path, text: "Play"
    assert_select ".nudge", text: "Your streak is safe for today, but you can keep playing to practise more."
  end

  test "after a missed day the streak starts again" do
    @user.update!(current_streak: 5, last_practised_on: @user.today - 2)
    sign_in_as @user

    get root_path
    assert_select ".nudge", text: "Click play to start your streak"
  end

  test "warns when the streak is at risk" do
    @user.update!(current_streak: 3, last_practised_on: @user.today - 1)
    sign_in_as @user

    get root_path
    assert_select ".nudge--risk", text: "Don't lose your streak!"
  end
end
