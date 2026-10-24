require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  include ActionView::Helpers::NumberHelper
  setup { @user = users(:ada) }

  test "a new visitor picks a topic first, then the home page is on it" do
    get root_path
    assert_redirected_to topics_path
    follow_redirect!
    assert_select "h1", text: "What do you want to practise?"
    assert_select ".topic-card", Topic::ALL.size
    assert_select ".topic-card--current", count: 0

    patch topic_path, params: { topic: "equations" }
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".current-topic", count: 0, message: "the topic is on Practice, not home"
    get practice_path
    assert_select ".current-topic__name", text: "Equations"

    get topics_path
    assert_select "h1", text: "Topics"
  end

  test "a player on a new device carries on with the topic they last played" do
    Attempt.record!(user: @user, topic: "functions", results: [ EASY_QUESTIONS.fetch(Functions) ] * 5)
    sign_in_as @user
    cookies.delete("topic")

    get practice_path
    assert_response :success
    assert_select ".current-topic__name", text: "Functions"
  end

  test "visitors can start playing without signing up" do
    choose_topic
    get root_path

    assert_response :success
    assert_select ".site-header .tagline", text: "Improve your math in minutes"
    assert_select ".greeting .streak", text: "0"
    assert_select ".home-actions a.button", 3
    assert_select ".home-actions a[href=?]", challenge_path, text: "Challenge"
    assert_select ".home-actions a[href=?]", practice_path, text: /Practice\s+Play to start a streak/
    assert_select ".home-actions a[href=?]", groups_path, text: "Compete"
    assert_select "a.button--play", count: 0, message: "playing is on Practice"
    assert_select "a[href=?]", new_registration_path

    get practice_path
    assert_select "a.button--play[href=?]", play_path("times-tables", level: 1), text: /Play level 1\s+Play to start a streak/
    assert_select "a.button--mixed", count: 0, message: "nothing to mix with only level 1"
  end

  test "Practice and the daily challenge have pages of their own, with the way home" do
    choose_topic
    get practice_path
    assert_select "a.back-link[href=?]", root_path
    assert_select ".levels"
    get challenge_path
    assert_select "h1", text: /Daily challenge/
    assert_select "a.back-link[href=?]", root_path
  end

  test "says maths to browsers set to the UK, and math to everyone else" do
    choose_topic
    get root_path, headers: { "Accept-Language" => "en-GB,en;q=0.9" }
    assert_select ".tagline", text: "Improve your maths in minutes"
    assert_select "html[lang=en-GB]"

    get root_path, headers: { "Accept-Language" => "en-US,en;q=0.9" }
    assert_select ".tagline", text: "Improve your math in minutes"
    assert_select "html[lang=en-US]"

    get root_path, headers: { "Accept-Language" => "fr-FR" }
    assert_select ".tagline", text: "Improve your math in minutes"
  end

  test "stars stay in the footer, and stars and freezes are on the settings page, not here" do
    sign_in_as users(:ada)
    Attempt.record!(user: users(:ada), results: answers(*right_answers(5), ms: 2_500))

    get root_path
    assert_select ".site-footer__gems", text: "210", message: "50 for the answers and 10 for the 5th in a row doubled, then a new high score and a level up"
    assert_select "main .gems-total", count: 0
    assert_select "main .freezes", count: 0
  end

  test "coming back after a missed day says a freeze kept the streak" do
    user = users(:ada)
    [ 4, 3, 2 ].each { |ago| travel_to(ago.days.ago) { play_daily_challenge(user) } }
    user.update!(streak_freezes: 1)
    sign_in_as user

    get root_path
    assert_select ".flash", text: "A streak freeze kept your 3 day streak going!"
    assert_select ".greeting .streak[aria-label=?]", "3 day streak", text: "3"
    assert_equal 0, user.reload.streak_freezes
  end

  test "greets the player by name" do
    @user.update!(name: "Ada")
    sign_in_as @user

    get root_path
    assert_select ".greeting", text: /Hi Ada!/
  end

  test "the page goes the greeting with the streak small beside it, then Challenge, Practice and Compete" do
    @user.update!(name: "Ada")
    sign_in_as @user
    get root_path

    parts = %w[ greeting streak home-actions ]
    order = css_select(parts.map { ".#{_1}" }.join(", ")).map { |element| (element["class"].split & parts).first }
    assert_equal parts, order
  end

  test "shows the streak, best score and start button" do
    @user.update!(current_streak: 12, last_practised_on: @user.today, streak_kept_on: @user.today)
    Attempt.record!(user: @user, results: answers(*right_answers(41), ms: 1000))
    @user.update!(current_streak: 12, last_practised_on: @user.today, streak_kept_on: @user.today)
    sign_in_as @user
    patch level_path, params: { level: 1 }

    Attempt.record!(user: @user, topic: "equations", results: [ EASY_QUESTIONS.fetch(Equations) ] * 2)
    @user.update!(current_streak: 12, longest_streak: 15, last_practised_on: @user.today, streak_kept_on: @user.today)
    get root_path
    assert_select ".greeting .streak", text: "12"
    assert_select ".home-action--practice .button__note", count: 0, message: "the streak is safe today"
    most = @user.attempts.maximum(:gems)
    assert_select ".stats div", text: /Most gems\s+#{number_with_delimiter(most)}/, message: "from any game"
    assert_select ".stats div", text: /Longest streak\s+15/

    get practice_path
    assert_equal %w[ Best\ score Average\ score Average\ time Most\ gems ], css_select(".stats dt").map(&:text)
    assert_select ".stats div", text: /Best score\s+41/
    assert_select ".stats div", text: /Most gems\s+#{number_with_delimiter(@user.attempts.at_level(TimesTables, 1).maximum(:gems))}/
    assert_select "a[href=?]", stats_path("times-tables"), text: "See all stats"
    assert_select "a.button--play[href=?]", play_path("times-tables", level: 1), text: /Play level 1\s+Beat your best: 41/, message: "the streak is safe today, so it's the best to beat"
    assert_select ".levels__level[aria-current=true] .levels__best", text: "41"
    assert_select ".nudge", count: 0
  end

  test "after a missed day the streak starts again" do
    @user.update!(current_streak: 5, last_practised_on: @user.today - 2, streak_kept_on: @user.today - 2)
    sign_in_as @user

    get root_path
    assert_select ".home-action--practice .button__note", text: "Play to start a streak"
    get practice_path
    assert_select ".button--play .button__note", text: "Play to start a streak"
  end

  test "warns when the streak is at risk" do
    @user.update!(current_streak: 3, last_practised_on: @user.today - 1, streak_kept_on: @user.today - 1)
    sign_in_as @user

    get root_path
    assert_select ".home-action--practice .button__note", text: "Don't lose your streak!"
    get practice_path
    assert_select ".button--play .button__note", text: "Don't lose your streak!"
  end

  test "a game in any topic keeps the streak, and Play stops nagging once one's played" do
    @user.update!(current_streak: 3, last_practised_on: @user.today - 1, streak_kept_on: @user.today - 1)
    Attempt.record!(user: @user, topic: "equations", results: [ EASY_QUESTIONS.fetch(Equations) ] * 2)
    sign_in_as @user

    get root_path
    assert_select ".button__note", count: 0
    get practice_path
    assert_select ".button--play", text: "Play level 1"
    assert_select ".button__note", count: 0
  end

  test "mixed practice once there's a second level to mix in, as often as they like" do
    unlock(@user, TimesTables, 2)
    sign_in_as @user
    get practice_path
    assert_select ".levels-panel a.button--mixed[href=?]", play_path("times-tables", mixed: 1), text: "Mixed practice"
  end
end
