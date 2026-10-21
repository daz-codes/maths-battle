require "application_system_test_case"

class EquationsTest < ApplicationSystemTestCase
  test "switch to equations, answer with the keyboard including fractions, and see the results" do
    sign_in users(:ada)
    click_on "Change topic"
    find(".topic-card", text: "Equations").click
    assert_selector ".levels__name", text: "Level 1: One step"
    click_on "Play level 1"
    assert_selector ".question var", wait: 5
    end_game_in(6_000)

    answered = []
    4.times do
      answer = current_answer
      find("body").send_keys(answer)
      answered << answer
      assert_selector ".test__score", text: answered.size.to_s
    end
    wrong = current_answer == "1" ? "2" : "1"
    find("body").send_keys(wrong) # a one-character answer is checked straight away, so this one's wrong unless the answer is 1

    assert_selector ".card__number", text: /\A[45]\z/, wait: 10
    assert_text "⚖️ EQUATIONS"
    assert_equal "equations", users(:ada).attempts.last.topic
  end

  test "a fraction answer can be typed with the on-screen keypad" do
    unlock(users(:ada), Equations, 5)
    sign_in users(:ada)
    visit play_path("equations", level: 5)
    assert_selector ".question var", wait: 5

    page.execute_script(<<~JS)
      const test = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller=test]"), "test")
      test.questions[test.index] = { type: "ax=b", a: 12, b: 9, v: "x", flip: false, text: "12<var>x</var> = 9", answer: "3/4" }
      test.show()
    JS
    %w[3 / 4].each { |key| find(".keypad__key[data-digit='#{key}']").execute_script("this.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }))") }
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
