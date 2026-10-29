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
    assert_select ".ui-home__heading", text: "Master Math in Minutes"
    assert_select ".site-header .ui-header__hello", text: "Hi there!"
    assert_select ".ui-header .streak strong", text: "0"
    assert_select ".home-actions a.button", 2, "Practice and Compete; the Daily Challenge's games are on its card"
    assert_select ".home-action--challenge a.ui-daily__game[href=?]", play_path("times-tables", daily: "tables"), text: /Tables Test\s*Play/
    assert_select ".home-action--challenge a.ui-daily__game[href=?]", play_path("sequences", daily: "patternz"), text: /Patternz\s*Play/
    assert_select ".ui-eyebrow", text: /Ready for another round/, count: 0
    assert_select "p", text: /A reason to come back/, count: 0
    assert_select ".home-actions a[href=?] .home-action__label", practice_path, text: "Practice"
    assert_select ".home-actions a[href=?] .home-action__label", groups_path, text: "Compete"
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
    assert_select "h1", text: /Daily Challenge/
    assert_select "a.back-link[href=?]", root_path
  end

  test "says maths to browsers set to the UK, and math to everyone else" do
    choose_topic
    get root_path, headers: { "Accept-Language" => "en-GB,en;q=0.9" }
    assert_select ".ui-home__heading", text: "Master Maths in Minutes"
    assert_select "html[lang=en-GB]"

    get root_path, headers: { "Accept-Language" => "en-US,en;q=0.9" }
    assert_select ".ui-home__heading", text: "Master Math in Minutes"
    assert_select "html[lang=en-US]"

    get root_path, headers: { "Accept-Language" => "fr-FR" }
    assert_select ".ui-home__heading", text: "Master Math in Minutes"
  end

  test "no gems or streak freezes anywhere: it's just the score" do
    sign_in_as users(:ada)
    Attempt.record!(user: users(:ada), results: answers(*right_answers(5), ms: 2_500))

    get root_path
    assert_select ".site-footer__gems", count: 0
    assert_select ".icon--gem", count: 0
    assert_select ".gems-total, .freezes", count: 0
  end

  test "a missed day loses the streak: a freeze held from before isn't used" do
    user = users(:ada)
    [ 4, 3, 2 ].each { |ago| travel_to(ago.days.ago) { play_daily_challenge(user) } }
    user.update!(streak_freezes: 1)
    sign_in_as user

    get root_path
    assert_select ".flash", text: /freeze/i, count: 0
    assert_select ".ui-header .streak strong", text: "0"
    assert_equal 1, user.reload.streak_freezes
  end

  test "greets the player by name" do
    @user.update!(name: "Ada")
    sign_in_as @user

    get root_path
    assert_select ".site-header .ui-header__hello", text: "Hi Ada!", message: "under the logo, beside their picture"
    assert_select ".site-header .ui-header__who a.ui-profile[href=?]", edit_profile_path
  end

  test "the heading under the logo, then the greeting with the streak beside it, then Challenge, Practice and Compete" do
    @user.update!(name: "Ada")
    sign_in_as @user
    get root_path

    parts = %w[ ui-home__heading ui-header__hello streak home-actions ]
    order = css_select(parts.map { ".#{_1}" }.join(", ")).map { |element| (element["class"].split & parts).first }
    assert_equal parts, order
  end

  test "shows the streak, best score and start button" do
    @user.update!(current_streak: 12, last_practised_on: @user.today, streak_kept_on: @user.today)
    best = Attempt.record!(user: @user, results: answers(*right_answers(41), ms: 1000)).score
    @user.update!(current_streak: 12, last_practised_on: @user.today, streak_kept_on: @user.today)
    sign_in_as @user
    patch level_path, params: { level: 1 }

    Attempt.record!(user: @user, topic: "equations", results: [ EASY_QUESTIONS.fetch(Equations) ] * 2)
    @user.update!(current_streak: 12, longest_streak: 15, last_practised_on: @user.today, streak_kept_on: @user.today)
    get root_path
    assert_select ".ui-header .streak strong", text: "12"
    assert_select ".home-action--practice .button__note", count: 0, message: "the streak is safe today"
    assert_select ".stats div", text: /High score\s*#{number_with_delimiter(@user.attempts.maximum(:score))}/, message: "from any game"
    assert_select ".stats div", text: /Longest streak\s*15/

    get practice_path
    assert_equal %w[ High\ score Average\ score Average\ time Most\ right ], css_select(".stats dt").map(&:text)
    assert_select ".stats div", text: /High score\s+#{number_with_delimiter(best)}/
    assert_select ".stats div", text: /Most right\s+41/
    assert_select "a[href=?]", stats_path("times-tables"), text: "See all stats"
    assert_select "a.button--play[href=?]", play_path("times-tables", level: 1), text: /Play level 1\s+Beat your best: #{best}/, message: "the streak is safe today, so it's the best to beat"
    assert_select ".levels__level[aria-current=true] .levels__best", text: best.to_s
    assert_select ".nudge", count: 0
  end

  test "after a missed day the streak starts again" do
    @user.update!(current_streak: 5, last_practised_on: @user.today - 2, streak_kept_on: @user.today - 2)
    sign_in_as @user

    get root_path
    assert_select ".home-action--practice .button__note", count: 0, message: "any game keeps the streak, not just practice"
    get practice_path
    assert_select ".button--play .button__note", text: "Play to start a streak"
  end

  test "warns when the streak is at risk" do
    @user.update!(current_streak: 3, last_practised_on: @user.today - 1, streak_kept_on: @user.today - 1)
    sign_in_as @user

    get root_path
    assert_select ".home-action--practice .button__note", count: 0
    get practice_path
    assert_select ".button--play .button__note", text: "Don't lose your streak!"
  end

  test "a game in any topic keeps the streak, and Play stops nagging once one's played" do
    @user.update!(current_streak: 3, last_practised_on: @user.today - 1, streak_kept_on: @user.today - 1)
    Attempt.record!(user: @user, topic: "equations", results: [ EASY_QUESTIONS.fetch(Equations) ] * 2)
    sign_in_as @user

    get root_path
    assert_select ".home-action--practice .button__note", count: 0
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
