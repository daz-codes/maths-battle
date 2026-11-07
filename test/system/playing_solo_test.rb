require "application_system_test_case"

class PlayingSoloTest < ApplicationSystemTestCase
  test "answering quickly brings harder questions, a power-up is claimed, and the game is saved" do
    visit root_path
    click_on "Single player"
    assert_selector ".question--current", text: /[×÷]/, wait: 5

    3.times { answer_question }
    assert_no_text "Level"
    assert_selector ".test__streak--hot [data-test-target=streak]", text: "3"
    assert_selector ".test__score", text: "60"
    answer_question(right: false)
    6.times { answer_question }
    assert_selector ".test__spinner"
    find(".test__spinner").click
    assert_selector ".test__spinner--landed"
    take_screenshot

    shorten_the_game
    assert_selector ".result", wait: 10
    attempt = Attempt.last
    assert_equal 9, attempt.correct
    assert_equal 1, attempt.powers.size
    assert_selector ".card__number", text: attempt.score.to_s
    take_screenshot
  end
end
