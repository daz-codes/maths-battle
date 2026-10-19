require "test_helper"

class LessonCompletionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:ada) }

  test "finishing a lesson is recorded, but only the daily challenge keeps the streak" do
    sign_in_as @user
    post lesson_completion_path("times-tables", 1), as: :json

    assert_response :created
    assert_equal 1, @user.lesson_completions.count
    travel_to(User::Streakable::DAILY_CHALLENGE_STREAKS_FROM.in_time_zone.change(hour: 12)) do
      @user.complete_lesson!(TimesTables, 1)
      assert_not @user.reload.practised_today?
    end
  end

  test "the same lesson again that day changes nothing" do
    sign_in_as @user
    2.times { post lesson_completion_path("times-tables", 1), as: :json }
    assert_equal 1, @user.lesson_completions.count
  end

  test "only for an unlocked level" do
    sign_in_as @user
    post lesson_completion_path("times-tables", 3), as: :json
    assert_response :unprocessable_entity
    post lesson_completion_path("equations", 9), as: :json
    assert_response :unprocessable_entity
  end

  test "a visitor finishing a lesson gets a guest account to keep it" do
    assert_difference -> { User.count } do
      post lesson_completion_path("times-tables", 1), as: :json
    end
    assert User.last.guest?
    assert_equal 1, User.last.lesson_completions.count
  end
end
