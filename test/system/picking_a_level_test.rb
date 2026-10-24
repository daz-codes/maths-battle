require "application_system_test_case"

class PickingALevelTest < ApplicationSystemTestCase
  test "picking a level keeps the page where it was, on Practice and stats" do
    unlock(users(:ada), TimesTables, 2)
    sign_in users(:ada)
    page.current_window.resize_to(400, 500)

    [ practice_path, stats_path ].each do |path|
      visit path
      page.execute_script("window.scrollTo(0, document.querySelector('.levels').getBoundingClientRect().top + window.scrollY - 100)")
      scrolled = page.evaluate_script("window.scrollY")
      assert_operator scrolled, :>, 100

      find(".levels__level", text: "1").click
      assert_selector ".levels__name", text: "Level 1"
      assert_in_delta scrolled, page.evaluate_script("window.scrollY"), 5, "on #{path}"
    end
  end
end
