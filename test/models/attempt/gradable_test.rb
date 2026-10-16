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

  test "a good game has 20 or more answered and 90% or more right" do
    good, too_few, too_many_wrong = game(right: 18, wrong: 2), game(right: 19), game(right: 17, wrong: 3)

    assert good.good?
    assert_not too_few.good?
    assert_not too_many_wrong.good?
    assert_equal [ good ], @user.attempts.good, "the scope and the check agree"
  end
end
