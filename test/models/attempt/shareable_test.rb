require "test_helper"

class Attempt::ShareableTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  test "a brag with score, streak, best, squares and link, but no questions or username" do
    play_daily_challenge(@user)
    attempt = record_tables_game(@user, answers([ 7, 8, 56 ], [ 6, 7, 41 ], [ 9, 9, 81 ], [ 2, 2, 4 ], [ 3, 3, 9 ]))
    text = attempt.share_text("https://matheminute.app/s/abc")

    assert_equal 4, attempt.correct
    assert_equal <<~TEXT.chomp, text
      MatheMinute ✖️ Times tables, level 2: #{attempt.score} (4 right in 60s)
      🔥 1 day streak  🏆 High score: #{attempt.score}
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
