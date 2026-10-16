require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:ada) }

  test "visitors can start playing without signing up" do
    get root_path

    assert_response :success
    assert_select ".site-header .tagline", text: "Improve your math, one minute at a time"
    assert_select "a[href=?]", play_path("times-tables"), text: "Play"
    assert_select ".streak__number", text: /0/
    assert_select ".nudge", text: "Click play to start your streak"
    assert_select "a[href=?]", new_registration_path
  end

  test "says maths to browsers set to the UK, and math to everyone else" do
    get root_path, headers: { "Accept-Language" => "en-GB,en;q=0.9" }
    assert_select ".tagline", text: "Improve your maths, one minute at a time"
    assert_select "html[lang=en-GB]"

    get root_path, headers: { "Accept-Language" => "en-US,en;q=0.9" }
    assert_select ".tagline", text: "Improve your math, one minute at a time"
    assert_select "html[lang=en-US]"

    get root_path, headers: { "Accept-Language" => "fr-FR" }
    assert_select ".tagline", text: /your math,/
  end

  test "greets the player by name" do
    @user.update!(name: "Ada")
    sign_in_as @user

    get root_path
    assert_select ".greeting", text: /Hi Ada!/
  end

  test "shows the streak, best score and start button" do
    @user.update!(current_streak: 12, last_practised_on: @user.today)
    Attempt.record!(user: @user, results: answers(*right_answers(41), ms: 1000))
    @user.update!(current_streak: 12, last_practised_on: @user.today)
    sign_in_as @user

    get root_path
    assert_select ".streak__number", text: /12/
    assert_select ".stats", text: /41/
    assert_select "a[href=?]", stats_path("times-tables"), text: "See all stats"
    assert_select "a[href=?]", play_path("times-tables"), text: "Play"
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
