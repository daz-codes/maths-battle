require "application_system_test_case"

class LevellingUpTest < ApplicationSystemTestCase
  test "negatives level: type a minus answer on the four-column keypad" do
    user = users(:ada)
    (1..4).each { |level| 5.times { Attempt.record!(user: user, level: level, results: answers(*Array.new(20) { [ 2, 3, 6 ] }, ms: 1000)) } }
    sign_in user

    assert_selector ".levels__name", text: "Level 5: Negatives"
    click_on "Practise level 5"
    assert_selector ".keypad--wide", wait: 5
    assert_selector ".question", text: "×", wait: 5

    page.execute_script(<<~JS)
      const test = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller=test]"), "test")
      test.questions[test.index] = { a: "0.7", b: "-3000", text: "0.7 × −3000", answer: "-2100" }
      test.show()
    JS
    %w[- 2 1 0 0].each { |key| find(".keypad__key[data-digit='#{key}']").execute_script("this.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }))") }
    assert_selector ".test__score", text: "1"

    page.execute_script(<<~JS)
      const test = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller=test]"), "test")
      test.questions[test.index] = { a: "0.4", b: "0.6", text: "0.4 × 0.6", answer: "0.24" }
      test.show()
    JS
    find("body").send_keys(".24") # a point before any digit starts the number with 0
    assert_selector ".test__score", text: "2"
  end
end
