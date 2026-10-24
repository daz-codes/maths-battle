require "application_system_test_case"

class TimesTablesTest < ApplicationSystemTestCase
  test "plays a test with the keyboard and sees the results" do
    sign_in users(:ada)
    click_on "Practice"
    click_on "Play level 1"

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
      a, b = find(".question--current").text.split(" × ").map(&:to_i)
      find("body").send_keys((a * b).to_s)
      assert_selector "[data-test-target=right]", text: /#{_1 + 1}/
    end

    a, b = find(".question--current").text.split(" × ").map(&:to_i)
    wrong = (a * b) % 10 == 9 ? a * b - 1 : a * b + 1 # same number of digits, so it's checked straight away
    find("body").send_keys(wrong.to_s)
    assert_selector ".answer--wrong", text: wrong.to_s
    assert_selector ".question-previous--wrong", text: "#{a} × #{b} = #{wrong} ✗ #{a * b}"

    assert_selector ".result__score", text: /\b2 right/, wait: 8
    assert_text "#{a} × #{b} = #{a * b}"
    assert_equal 2, users(:ada).best_correct(TimesTables, 1)
  end

  test "the answered question drops below the next, marked like a teacher would: a tick, or a cross and the right answer" do
    sign_in users(:ada)
    click_on "Practice"
    click_on "Play level 1"
    assert_selector ".question--current", text: "×", wait: 5
    size = find(".question--current")[:class]

    a, b = find(".question--current").text.split(" × ").map(&:to_i)
    find("body").send_keys((a * b).to_s)
    assert_selector ".question-previous.question-previous--right", exact_text: "#{a} × #{b} = #{a * b} ✓"
    assert_selector ".answer", exact_text: "", visible: :all
    assert_selector ".test__score", text: /\A[1-9]\d*\z/
    assert_selector "[data-test-target=right]", text: "1"

    a, b = find(".question--current").text.split(" × ").map(&:to_i)
    wrong = (a * b) % 10 == 9 ? a * b - 1 : a * b + 1
    find("body").send_keys(wrong.to_s)
    assert_selector ".answer.answer--wrong", text: wrong.to_s
    assert_selector ".question-previous.question-previous--wrong", exact_text: "#{a} × #{b} = #{wrong} ✗ #{a * b}"
    assert_selector ".answer:not(.answer--wrong)", exact_text: "", visible: :all
    assert_equal size, find(".question--current")[:class], "every question the same size"
  end

  test "gems float up for each right answer and its speed, a combo multiplies them, and a wrong answer loses some" do
    sign_in users(:ada)
    click_on "Practice"
    click_on "Play level 1"
    assert_selector ".question", text: "×", wait: 5

    a, b = find(".question--current").text.split(" × ").map(&:to_i)
    find("body").send_keys((a * b).to_s)
    assert_no_selector ".score-pop .icon--gem", visible: :all
    assert_selector ".score-pop.score-pop--right", text: "+10"
    assert_selector ".score-pop.score-pop--lightning", text: "+20"
    assert_selector ".score-pop.score-pop--lightning .icon--lightning", visible: :all
    assert_selector ".test__combo", visible: :hidden

    4.times do |answered|
      a, b = find(".question--current").text.split(" × ").map(&:to_i)
      find("body").send_keys((a * b).to_s)
      assert_selector "[data-test-target=right]", text: /#{answered + 2}/
    end
    assert_selector ".test__combo", text: "×2"
    assert_selector ".score-pop--combo", text: "×2!"
    assert_selector ".score-pop.score-pop--right", text: "+20"

    a, b = find(".question--current").text.split(" × ").map(&:to_i)
    wrong = (a * b) % 10 == 9 ? a * b - 1 : a * b + 1
    find("body").send_keys(wrong.to_s)
    assert_selector ".score-pop.score-pop--wrong", text: "−5"
    assert_selector ".test__combo", visible: :hidden
    assert_no_selector ".score-pop", wait: 4
  end

  test "one game played to the end keeps the streak, and Play stops asking for one" do
    sign_in users(:ada)
    click_on "Practice"
    assert_selector ".button--play", text: /Play to start a streak/i
    click_on "Play level 1"
    page.execute_script(<<~JS)
      const waitForStart = setInterval(() => {
        const element = document.querySelector("[data-controller=test]")
        const test = element && window.Stimulus.getControllerForElementAndIdentifier(element, "test")
        if (test?.state === "running") { test.endsAt = performance.now() + 3000; clearInterval(waitForStart) }
      }, 10)
    JS
    assert_selector ".question", text: "×", wait: 5
    a, b = find(".question--current").text.split(" × ").map(&:to_i)
    find("body").send_keys((a * b).to_s)

    assert_selector ".result__score", text: /\b1 right/, wait: 8
    visit root_path
    assert_selector ".greeting .streak", text: "1"
    assert_no_selector ".home-action--practice .button__note", text: /streak/i
  end

  test "passing your best mid-game: the score turns pink and says so" do
    Attempt.record!(user: users(:ada), results: answers([ 2, 3, 6 ], ms: 500)) # one lightning fast answer: 30
    sign_in users(:ada)
    click_on "Practice"
    click_on "Play level 1"
    assert_selector ".test__best", text: "Best 30"
    assert_selector ".question", text: "×", wait: 5

    a, b = find(".question--current").text.split(" × ").map(&:to_i)
    find("body").send_keys((a * b).to_s)
    assert_no_selector ".test--beating"
    a, b = find(".question--current").text.split(" × ").map(&:to_i)
    find("body").send_keys((a * b).to_s)

    assert_selector ".test--beating .test__best", text: "New best!"
    assert_selector ".score-pop--best .icon--trophy", visible: :all
    assert_selector ".score-pop--best", text: "New best!"
  end
end
