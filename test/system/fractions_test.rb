require "application_system_test_case"

class FractionsTest < ApplicationSystemTestCase
  test "pick fractions, simplify with the keyboard and the fraction key, and see the results" do
    sign_in users(:ada)
    click_on "Change topic"
    find(".topic-card", text: "Fractions").click
    assert_selector ".levels__name", text: "Level 1: Simplifying"
    click_on "Play level 1"
    assert_selector ".question .question__verb", text: "Simplify", wait: 5
    assert_selector ".question .frac", count: 1
    end_game_in(6_000)

    3.times do |i|
      find("body").send_keys(current_answer)
      assert_selector ".test__score", text: (i + 1).to_s
    end

    assert_selector ".card__number", text: "3", wait: 10
    assert_text "FRACTIONS, LEVEL 1"
    assert_equal "fractions", users(:ada).attempts.last.topic
  end

  test "two fractions to add, stacked, answered on the on-screen keypad" do
    unlock(users(:ada), Fractions, 3)
    sign_in users(:ada)
    visit play_path("fractions", level: 3)
    assert_selector ".question .frac", count: 2, wait: 5

    page.execute_script(<<~JS)
      const test = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller=test]"), "test")
      test.questions[test.index] = { type: "add-diff", a: 1, b: 3, c: 1, d: 4, text: test.current.text, answer: "7/12" }
      test.show()
    JS
    %w[7 / 1 2].each { |key| find(".keypad__key[data-digit='#{key}']").execute_script("this.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }))") }
    assert_selector ".test__score", text: "1"
  end

  private
    def end_game_in(ms)
      page.execute_script(<<~JS)
        const test = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller=test]"), "test")
        test.endsAt = performance.now() + #{ms}
        clearTimeout(test.endTimer)
      JS
    end

    def current_answer
      page.evaluate_script(%(window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller=test]"), "test").current.answer))
    end
end
