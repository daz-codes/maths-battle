require "application_system_test_case"

class NewTopicsTest < ApplicationSystemTestCase
  test "division: pick it, answer with the keyboard, and see the results" do
    sign_in users(:ada)
    click_on "Change topic"
    find(".topic-card", text: "Division").click
    assert_selector ".levels__name", text: "Level 1: Tables 2–5"
    click_on "Practise level 1"
    assert_selector ".question", text: "÷", wait: 5
    end_game_in(6_000)

    3.times do |i|
      find("body").send_keys(current_answer)
      assert_selector ".test__score", text: (i + 1).to_s
    end

    assert_selector ".card__number", text: "3", wait: 10
    assert_equal "division", users(:ada).attempts.last.topic
  end

  test "negative numbers: a minus answer typed on the keypad" do
    sign_in users(:ada)
    click_on "Change topic"
    find(".topic-card", text: "Negative numbers").click
    click_on "Practise level 1"
    assert_selector ".question", text: "−", wait: 5

    page.execute_script(<<~JS)
      const test = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller=test]"), "test")
      test.questions[test.index] = { type: "below-zero", a: 4, b: 9, text: "4 − 9", answer: "-5" }
      test.show()
    JS
    %w[- 5].each { |key| find(".keypad__key[data-digit='#{key}']").execute_script("this.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }))") }
    assert_selector ".test__score", text: "1"
  end

  test "adding and subtracting: pick it, answer with the keyboard, and see the results" do
    sign_in users(:ada)
    click_on "Change topic"
    find(".topic-card", text: "Adding and subtracting").click
    assert_selector ".levels__name", text: "Level 1: Single digits"
    click_on "Practise level 1"
    assert_selector ".question", text: /[+−]/, wait: 5
    end_game_in(6_000)

    3.times do |i|
      find("body").send_keys(current_answer)
      assert_selector ".test__score", text: (i + 1).to_s
    end

    assert_selector ".card__number", text: "3", wait: 10
    assert_equal "addition", users(:ada).attempts.last.topic
  end

  test "percentages: pick it, answer with the keyboard, and see the results" do
    sign_in users(:ada)
    click_on "Change topic"
    find(".topic-card", text: "Percentages").click
    assert_selector ".levels__name", text: "Level 1: 50% and 10%"
    click_on "Practise level 1"
    assert_selector ".question", text: "% of", wait: 5
    end_game_in(6_000)

    3.times do |i|
      find("body").send_keys(current_answer)
      assert_selector ".test__score", text: (i + 1).to_s
    end

    assert_selector ".card__number", text: "3", wait: 10
    assert_equal "percentages", users(:ada).attempts.last.topic
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
