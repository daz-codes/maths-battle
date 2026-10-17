require "application_system_test_case"

class SimultaneousEquationsTest < ApplicationSystemTestCase
  test "pick simultaneous equations, find y then x for each pair, and see the results" do
    sign_in users(:ada)
    select "🔗 Simultaneous equations", from: "Topic"
    assert_selector ".levels__name", text: "Level 1: Subtract"
    click_on "Play"
    assert_selector ".question .system__ask", text: "y =", wait: 5
    end_game_in(6_000)

    find("body").send_keys(current_answer)
    assert_selector ".question .system__known", text: "y ="
    assert_selector ".question .system__ask", text: "x ="
    find("body").send_keys(current_answer)
    assert_selector ".test__score", text: "2"

    assert_selector ".card__number", text: /\A[23]\z/, wait: 10
    assert_text "🔗 SIMULTANEOUS EQUATIONS"
    assert_equal "simultaneous", users(:ada).attempts.last.topic
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
