require "application_system_test_case"

class TimesTablesTest < ApplicationSystemTestCase
  test "plays a test with the keyboard and sees the results" do
    sign_in users(:ada)
    click_on "Play"

    # Shorten the minute so the test runs quickly; the countdown still plays first
    page.execute_script(<<~JS)
      const waitForStart = setInterval(() => {
        const element = document.querySelector("[data-controller=test]")
        const test = element && window.Stimulus.getControllerForElementAndIdentifier(element, "test")
        if (test?.state === "running") { test.endsAt = performance.now() + 4000; clearInterval(waitForStart) }
      }, 10)
    JS

    assert_selector ".question", text: "×", wait: 5

    # Two right answers then a wrong one, typed with no Enter key
    2.times do
      a, b = find(".question").text.split(" × ").map(&:to_i)
      find("body").send_keys((a * b).to_s)
      assert_selector ".test__score", text: /#{_1 + 1}/
    end

    a, b = find(".question").text.split(" × ").map(&:to_i)
    wrong = (a * b) % 10 == 9 ? a * b - 1 : a * b + 1 # same number of digits, so it's checked straight away
    find("body").send_keys(wrong.to_s)
    assert_selector ".answer--wrong", text: (a * b).to_s

    assert_selector ".card__number", text: "2", wait: 8
    assert_text "#{a} × #{b} = #{a * b}"
    assert_equal 2, users(:ada).best_score(TimesTables, 1)
  end

  test "each right answer's stars float up and fade away" do
    sign_in users(:ada)
    click_on "Play"
    assert_selector ".question", text: "×", wait: 5

    a, b = find(".question").text.split(" × ").map(&:to_i)
    find("body").send_keys((a * b).to_s)
    assert_selector ".star-pop.star-pop--lightning", text: "+30 ⭐"
    assert_no_selector ".star-pop", wait: 3
  end
end
