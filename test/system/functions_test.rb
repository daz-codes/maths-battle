require "application_system_test_case"

class FunctionsTest < ApplicationSystemTestCase
  test "pick functions from the dropdown, answer with the keyboard, and see the results" do
    sign_in users(:ada)
    select "⚙️ Functions", from: "Topic"
    assert_selector ".levels__name", text: "Level 1: Linear"
    click_on "Play"
    assert_selector ".question .function--ask", wait: 5
    end_game_in(6_000)

    3.times do |i|
      find("body").send_keys(current_answer)
      assert_selector ".test__score", text: (i + 1).to_s
    end

    assert_selector ".card__number", text: "3", wait: 10
    assert_text "⚙️ FUNCTIONS"
    assert_equal "functions", users(:ada).attempts.last.topic
  end

  test "a negative answer can be typed with the minus key" do
    unlock(users(:ada), Functions, 2)
    sign_in users(:ada)
    visit play_path("functions", level: 2)
    assert_selector ".question .function--ask", wait: 5

    page.execute_script(<<~JS)
      const test = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller=test]"), "test")
      test.questions[test.index] = { type: "x-a", a: 5, n: 2, text: "f(x) = x − 5, f(2)", answer: "-3" }
      test.show()
    JS
    %w[- 3].each { |key| find(".keypad__key[data-digit='#{key}']").execute_script("this.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }))") }
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
