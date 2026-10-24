require "application_system_test_case"

class AnswerControlsTest < ApplicationSystemTestCase
  test "a shorter wrong answer can be submitted with Enter or the check button" do
    click_on "Play level 1"
    assert_selector ".question", text: "×", wait: 5
    # Pick a real issued question with a two-digit answer, rather than changing its maths.
    page.execute_script(<<~JS)
      const game = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller=test]'), 'test')
      game.index = game.questions.findIndex(question => question.answer.length === 2)
      game.show()
    JS
    find("body").send_keys("1", :enter)
    assert_selector ".answer--wrong"
    assert_equal 1, result_count
    assert_selector ".question-previous--wrong", wait: 2, text: "✗"

    # A synthetic click is how assistive technologies activate the native keypad buttons.
    page.execute_script("document.querySelector('.keypad [data-digit=\"1\"]').click()")
    page.execute_script("document.querySelector('.keypad__key--submit').click()")
    assert_equal 2, result_count
  end

  test "a focused keypad button responds to Enter and Space without duplicate input" do
    click_on "Play level 1"
    assert_selector ".question", text: "×", wait: 5
    page.execute_script(<<~JS)
      const game = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller=test]'), 'test')
      game.index = game.questions.findIndex(question => question.answer.length === 2)
      game.show()
      document.querySelector('.keypad [data-digit="1"]').focus()
    JS
    find('.keypad [data-digit="1"]').send_keys(:enter)
    assert_selector ".answer", exact_text: "1"
    find('.keypad [data-digit="1"]').send_keys(:space)
    assert_equal 1, result_count
  end

  test "a shorter lesson answer can be checked and retried" do
    click_on "Learn how"
    4.times { click_on "Next" }
    find("body").send_keys("3", :enter)
    assert_selector ".lesson__feedback", text: "Not quite"
    assert_no_selector ".answer--wrong", wait: 2
    find("body").send_keys("15")
    assert_selector ".lesson__done", text: "That's it!"
  end

  private
    def result_count
      page.evaluate_script("window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller=test]'), 'test').results.length")
    end
end
