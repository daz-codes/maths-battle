require "test_helper"

class LessonCompletionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:ada) }

  test "finishing a lesson keeps the streak going for the day" do
    sign_in_as @user
    post lesson_completion_path("times-tables", 1), as: :json

    assert_response :success
    assert_equal 1, response.parsed_body["streak"]
    assert @user.reload.practised_today?
    assert_equal 1, @user.lesson_completions.count
  end

  test "the same lesson again that day changes nothing" do
    sign_in_as @user
    2.times { post lesson_completion_path("times-tables", 1), as: :json }
    assert_equal 1, @user.lesson_completions.count
  end

  test "lessons on days in a row make a streak, with games too" do
    travel_to(2.days.ago) { @user.complete_lesson!(TimesTables, 1) }
    travel_to(1.day.ago) { Attempt.record!(user: @user, results: answers(*right_answers(5))) }
    @user.complete_lesson!(TimesTables, 1)

    assert_equal 3, @user.reload.streak
  end

  test "only for an unlocked level with a lesson" do
    sign_in_as @user
    post lesson_completion_path("times-tables", 3), as: :json
    assert_response :unprocessable_entity
    post lesson_completion_path("equations", 1), as: :json
    assert_response :unprocessable_entity
  end

  test "a visitor finishing a lesson gets a guest account to keep the streak" do
    assert_difference -> { User.count } do
      post lesson_completion_path("times-tables", 1), as: :json
    end
    assert User.last.guest?
    assert_equal 1, response.parsed_body["streak"]
  end
end
