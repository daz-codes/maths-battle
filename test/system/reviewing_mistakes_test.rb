require "application_system_test_case"

class ReviewingMistakesTest < ApplicationSystemTestCase
  test "a review asks each mistake once with no clock, shows the answer to one got wrong, then says how it went" do
    Attempt.record!(user: users(:ada), results: answers([ 3, 5, 14 ], [ 2, 5, 11 ], [ 2, 3, 6 ]))
    sign_in users(:ada)
    click_on "Review mistakes (2)"

    assert_selector ".question", text: "×", wait: 5
    assert_selector ".test__bar", text: "1/2"
    assert_no_selector ".test__seconds", text: "60"

    a, b = find(".question--current").text.split(" × ").map(&:to_i)
    find("body").send_keys((a * b).to_s)
    assert_selector ".test__bar", text: "2/2"
    assert_no_selector ".gem-pop"

    a, b = find(".question--current").text.split(" × ").map(&:to_i)
    find("body").send_keys((a * b + 1).to_s)
    assert_selector ".answer--wrong", text: (a * b + 1).to_s
    assert_selector ".question-previous--wrong", text: "#{a} × #{b} = #{a * b + 1} ✗ #{a * b}", wait: 3

    assert_selector ".result__score", text: /1\s+of 2 right/, wait: 8
    assert_text "Mistakes reviewed +50"
    click_on "Review 1 more"
    assert_selector ".question", text: "#{a} × #{b}", wait: 5
  end
end
