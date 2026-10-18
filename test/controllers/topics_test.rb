require "test_helper"

class TopicsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:ada)
    sign_in_as @user
  end

  test "the switcher changes what Play plays, and is remembered" do
    get root_path
    assert_select "a.button--practise[href=?]", play_path("times-tables", level: 1)

    patch topic_path, params: { topic: "equations" }
    assert_redirected_to root_path
    follow_redirect!
    assert_select "a.button--practise[href=?]", play_path("equations", level: 1)
    assert_select "form.topic-picker[action=?] select[name=topic] option[selected][value=equations]", topic_path, text: "⚖️ Equations"
  end

  test "the dropdown lists every topic, and on the stats page goes to that topic's stats" do
    get root_path
    assert_select ".topic-picker select[data-action='auto-submit#submit'] option", Topic::ALL.size
    assert_select ".topic-picker option[value=functions]", text: "⚙️ Functions"

    get stats_path, params: { topic: "functions" }
    assert_response :success
    assert_select ".topic-picker option[selected][value=functions]"
    assert_select ".aside", text: "Play a game of functions and your stats will show up here."
  end

  test "playing a topic makes it the current one" do
    get play_path("equations")
    get root_path
    assert_select "a.button--practise[href=?]", play_path("equations", level: 1)
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
    Attempt.record!(user: @user, results: answers(*right_answers(20)))
    equations = Attempt.record!(user: @user, topic: "equations", results: [ { type: "ax=b", a: 3, b: 12, v: "x", flip: false, given: "4", ms: 2000 } ] * 6)

    assert equations.new_high_score, "a first equations game is a best, even after a bigger times tables score"
    assert_equal [ 20, 6 ], [ @user.best_score(TimesTables, 1), @user.best_score(Equations, 1) ]

    get stats_path("equations", level: 1)
    assert_select ".topic-picker option[selected][value=equations]"
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
