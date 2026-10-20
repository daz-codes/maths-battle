require "test_helper"

class LessonsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:ada) }

  test "a lesson shows its steps, then one to try with the level's keypad" do
    get lesson_path("times-tables", 1)

    assert_response :success
    assert_select ".lesson__title", text: "Tables 2–5"
    assert_select ".lesson__step[data-tutorial-target=step]", 4
    assert_select ".lesson__step[data-tutorial-target=step]:not([hidden])", 1, "one step at a time"
    assert_select ".lesson__try .lesson__show", text: "5 × 3"
    assert_select ".lesson__hint[hidden]", text: /Count up in 3s/
    assert_select "[data-tutorial-answer-value='15']"
    assert_select ".keypad__key[data-action~='pointerdown->tutorial#tap'][data-action~='click->tutorial#tap']", 11
    assert_select ".keypad__key--submit[data-action='tutorial#checkAnswer']", text: "Check answer"
    assert_select ".lesson__done a[href=?]", play_path("times-tables", level: 1), text: "Play level 1"
  end

  test "a level's keys come with its lesson" do
    sign_in_as @user
    unlock(@user, TimesTables, 5)

    get lesson_path("times-tables", 5)
    assert_select "[data-tutorial-answer-value='240']"
    assert_select ".keypad__key[data-digit='.']"
    assert_select ".keypad__key[data-digit='-']", count: 0, message: "times tables has no negatives"

    unlock(@user, Negatives, 5)
    get lesson_path("negative-numbers", 5)
    assert_select "[data-tutorial-answer-value='-56']"
    assert_select ".keypad__key[data-digit='-']"
  end

  test "a locked level's lesson waits until it's unlocked" do
    get lesson_path("times-tables", 3)
    assert_redirected_to root_path
  end

  test "every topic's lesson is written by the topic, as in its game" do
    sign_in_as @user
    unlock(@user, Equations, 2)
    get lesson_path("equations", 2)
    assert_select ".lesson__try .lesson__show", text: /\A\s*7 = x\s*6\s*\z/ do
      assert_select ".frac", 1
    end

    get lesson_path("simultaneous-equations", 1)
    assert_select ".lesson__try .system__row", 2
    assert_select ".lesson__step .lesson__line", text: "3x + 5y = 11"
    assert_select ".lesson__done .lesson__say", text: "4x + 3y = 18 and 3x + 3y = 15, so x = 3"
  end

  test "the home page offers the lesson for the level picked, in every topic" do
    choose_topic
    get root_path
    assert_select ".levels__learn a[href=?]", lesson_path("times-tables", 1), text: "📖 Learn how"

    patch topic_path, params: { topic: "functions" }
    get root_path
    assert_select ".levels__learn a[href=?]", lesson_path("functions", 1)
  end

  test "levelling up offers the new level's lesson" do
    sign_in_as @user
    unlock(@user, TimesTables, 2)
    levelled_up = @user.attempts.find_by!(levelled_up: true)

    get attempt_path(levelled_up)
    assert_select "a[href=?]", lesson_path("times-tables", 2), text: "📖 Learn how to do level 2"
  end
end
