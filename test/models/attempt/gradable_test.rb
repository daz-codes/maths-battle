require "test_helper"

class Attempt::GradableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  def game(right:, wrong: 0)
    Attempt.record!(user: @user, results: answers(*Array.new(right) { [ 2, 3, 6 ] }, *Array.new(wrong) { [ 2, 3, 1 ] }, ms: 500))
  end

  test "a game counts once enough questions are answered" do
    short, long = game(right: 4), game(right: 5)

    assert_not short.counted?
    assert long.counted?
    assert_equal [ long ], @user.attempts.counted
  end
end
