require "application_system_test_case"

class CelebratingTest < ApplicationSystemTestCase
  test "a new best is celebrated the first time its results show, not again when they're opened later" do
    user = users(:ada)
    Attempt.record!(user: user, results: answers([ 2, 3, 6 ]))
    best = Attempt.record!(user: user, results: answers([ 2, 3, 6 ], [ 2, 4, 8 ]))
    sign_in user

    visit attempt_path(best)
    assert_selector "main[data-celebration=new]"
    assert_selector ".banner[data-reveal-target=item]", visible: :hidden, text: /New high score/, wait: 0.3

    visit root_path
    visit attempt_path(best)
    assert_selector "main[data-celebration=seen]"
    assert_selector ".banner", visible: true, text: /New high score/, wait: 0.3
    assert_no_selector "canvas"
  end
end
