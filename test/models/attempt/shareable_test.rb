require "test_helper"

class Attempt::ShareableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  test "a brag with score, streak, best, squares and link, but no questions or username" do
    attempt = Attempt.record!(user: @user, results: answers([ 7, 8, 56 ], [ 6, 7, 41 ], [ 9, 9, 81 ], [ 2, 2, 4 ], [ 3, 3, 9 ]))
    text = attempt.share_text("https://matheminute.app/s/abc")

    assert_equal <<~TEXT.chomp, text
      MatheMinute ✖️ 4 in 60s
      🔥 1 day streak  🏆 Best: 4
      🟩🟥🟩🟩🟩
      https://matheminute.app/s/abc
    TEXT
    assert_no_match "ada", text
    assert_no_match "×", text
  end

  test "caps the squares at 40" do
    attempt = Attempt.record!(user: @user, results: answers(*right_answers(45), ms: 500))
    row = attempt.emoji_row

    assert_equal "🟩" * 40 + "…", row
  end

  test "no ellipsis when the squares fit" do
    attempt = Attempt.record!(user: @user, results: answers(*right_answers(40), ms: 500))
    assert_equal "🟩" * 40, attempt.emoji_row
  end
end
