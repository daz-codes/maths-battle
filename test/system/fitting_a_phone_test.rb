require "application_system_test_case"

class FittingAPhoneTest < ApplicationSystemTestCase
  teardown { page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") }

  test "every page fits a small phone's width, with nothing to scroll sideways" do
    play(users(:bob), rights: [ true ] * 8)
    sign_in users(:ada)
    attempt = play(users(:ada), rights: [ true ] * 12)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 360, height: 740, deviceScaleFactor: 2, mobile: true)
    [ root_path, multiplayer_path, leagues_path, match_path, awards_path, how_it_works_path, attempt_path(attempt), edit_profile_path, play_path ].each do |path|
      visit path
      assert_selector "main"
      widths = page.evaluate_script("[ document.documentElement.scrollWidth, document.documentElement.clientWidth ]")
      assert_equal widths.last, widths.first, "#{path} is wider than the screen"
      assert_equal "clip", page.evaluate_script("getComputedStyle(document.documentElement).overflowX"), "#{path} can't be panned sideways"
    end
  end
end
