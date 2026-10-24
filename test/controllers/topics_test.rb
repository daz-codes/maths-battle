require "test_helper"

class TopicsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:ada)
    sign_in_as @user
  end

  test "the switcher changes what Play plays, and is remembered, back on the page it was changed from" do
    get practice_path
    assert_select "a.button--play[href=?]", play_path("times-tables", level: 1)
    assert_select "a.current-topic[href=?]", topics_path(from: :practice)

    patch topic_path, params: { topic: "equations", from: "practice" }
    assert_redirected_to practice_path
    follow_redirect!
    assert_select "a.button--play[href=?]", play_path("equations", level: 1)
    assert_select ".current-topic__name", text: "Equations"
  end

  test "Practice says which topic, and tapping it goes to change it" do
    get practice_path
    assert_select ".current-topic__name", text: "Times tables"
    assert_select "a.current-topic[href=?][title='Change topic'][aria-label=?]", topics_path(from: :practice), "Times tables. Change topic"
    assert_select "select", count: 0
  end

  test "the settings page says which topic too, and changing it from there comes back there" do
    get edit_profile_path
    assert_select ".current-topic__name", text: "Times tables"
    assert_select "a.current-topic[href=?]", topics_path(from: "profile")

    patch topic_path, params: { topic: "functions", from: "profile" }
    assert_redirected_to edit_profile_path
    follow_redirect!
    assert_select ".current-topic__name", text: "Functions"
  end

  test "changing topic is a page of every topic with the player's progress, the current one marked" do
    Attempt.record!(user: @user, results: answers(*Array.new(12) { [ 2, 3, 6 ] }))
    Attempt.record!(user: @user, topic: "functions", level: 1, mode: "challenge", results: [ { type: "x+a", a: 2, n: 3, given: "5", ms: 1000 } ] * 5)
    get topics_path

    assert_select ".topic-card", Topic::ALL.size
    assert_select ".topic-card--current[aria-current=true]", 1 do
      assert_select ".topic-card__title", text: /Times tables · On it now/
      assert_select ".topic-card__level", text: "Level 2 of 5"
      assert_select ".topic-card__step:first-child .topic-card__number", text: "1"
      assert_select ".topic-card__step .stars[aria-label='2 of 3 stars']"
      assert_select ".topic-card__step--locked .icon--lock", 3
    end
    assert_select "form[action=?]:has(input[name=topic][value=functions]) .topic-card__done", topic_path, text: "Played today"
  end

  test "picking a topic makes it the current one, back where the player came from" do
    patch topic_path, params: { topic: "functions" }
    assert_redirected_to root_path

    get topics_path(from: "stats")
    assert_select "form input[name=from][value=stats]", Topic::ALL.size
    patch topic_path, params: { topic: "equations", from: "stats" }
    assert_redirected_to stats_path
    follow_redirect!
    assert_select ".current-topic__name", text: "Equations"
    assert_select "a.current-topic[href=?]", topics_path(from: "stats")
  end

  test "a stats page for a topic can still be linked to" do
    get stats_path, params: { topic: "functions" }
    assert_response :success
    assert_select ".current-topic__name", text: "Functions"
    assert_select ".aside", text: "Play a game of functions and your stats will show up here."
  end

  test "playing a topic makes it the current one" do
    get play_path("equations")
    get practice_path
    assert_select "a.button--play[href=?]", play_path("equations", level: 1)
  end

  test "the equations fractions level has a fraction key; other levels and times tables don't" do
    get play_path("equations")
    assert_select ".keypad__key[data-digit='/']", count: 0

    unlock(@user, Equations, 5)
    get play_path("equations", level: 5)
    assert_select ".keypad__key[data-digit='/']", text: "/"

    get play_path("times-tables")
    assert_select ".keypad__key[data-digit='/']", count: 0
  end

  test "unknown topics aren't found" do
    get play_path("algebra-9000")
    assert_response :not_found
  end

  test "the old times tables address still works" do
    get "/times-tables"
    assert_redirected_to "/play/times-tables"
  end

  test "best scores and stats are per topic" do
    tables = Attempt.record!(user: @user, results: answers(*right_answers(20)))
    equations = Attempt.record!(user: @user, topic: "equations", results: [ { type: "ax=b", a: 3, b: 12, v: "x", flip: false, given: "4", ms: 2000 } ] * 6)

    assert equations.new_high_score, "a first equations game is a best, even after a bigger times tables score"
    assert_equal [ tables.score, equations.score ], [ @user.best_score(TimesTables, 1), @user.best_score(Equations, 1) ]

    get stats_path("equations", level: 1)
    assert_select ".current-topic__name", text: "Equations"
    assert_select "thead th", text: "Type"
    assert_select "tbody th", text: /ax = b\s+e\.g\. 3x = 12/
    assert_select ".stats dd", text: "100%"
  end

  test "equations feedback names the type to practise" do
    unlock(@user, Equations, 3)
    attempt = Attempt.record!(user: @user, topic: "equations", level: 3, results: [ { type: "ax+b=c", a: 2, b: 7, c: 11, v: "y", flip: false, given: "3", ms: 2000 } ] * 6)

    assert_equal "Practise equations like 2x + 7 = 11", attempt.feedback_message
    assert_equal [ "2y + 7 = 11, so y = 2" ], attempt.missed_facts
  end
end
