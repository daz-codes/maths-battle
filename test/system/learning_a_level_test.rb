require "application_system_test_case"

class LearningALevelTest < ApplicationSystemTestCase
  test "tap through the worked example, get the one to try wrong then right, and go to play" do
    visit root_path
    click_on "📖 Learn how"
    assert_selector ".lesson__show", text: "4 × 3"

    3.times { click_on "Next" }
    assert_selector ".lesson__show", text: "3 × 4 = 12"
    click_on "Next"
    assert_selector ".lesson__try .lesson__show", text: "5 × 3"
    assert_no_button "Next"

    find("body").send_keys("12")
    assert_selector ".lesson__feedback", text: "Not quite"
    assert_selector ".lesson__hint", text: /Count up in 3s/

    assert_no_selector ".answer--wrong", wait: 2
    find("body").send_keys("15")
    assert_selector ".lesson__done", text: "That's it!"
    assert_selector ".lesson__streak", text: "🔥 1 day streak: that counts for today!"
    assert_selector ".lesson__dot--done", count: 5

    click_on "Play level 1"
    assert_selector ".question", wait: 5
  end
end
