require "application_system_test_case"

class DesignPreviewsTest < ApplicationSystemTestCase
  setup do
    FileUtils.mkdir_p("/tmp/matheminute-design-review")
    @user = users(:ada)
    @user.update!(name: "Ada")
    @attempt = record_tables_game(@user, answers(*right_answers(18), ms: 1000))
    sign_in(@user)
  end

  test "all three designs work across the app at phone and desktop sizes" do
    %w[ sprint bunch arcade ].each do |design|
      viewport(390, 844)
      visit root_path(design: design)
      assert_selector "html[data-design=#{design}]"
      assert_selector ".design-home__heading"
      assert_no_overflow
      capture("#{design}-home-mobile")

      within("main") { click_on "Practice", exact: false }
      assert_selector ".current-topic__name", text: "Times tables"
      assert_no_overflow
      capture("#{design}-practice-mobile")

      visit challenge_path
      assert_selector "h1", text: /Daily/
      assert_no_overflow
      capture("#{design}-daily-mobile")
      visit groups_path
      assert_selector "h1", text: "Compete"
      assert_no_overflow
      capture("#{design}-compete-mobile")
      visit attempt_path(@attempt)
      assert_selector ".result"
      assert_no_overflow
      capture("#{design}-results-mobile")

      visit play_path("times-tables")
      assert_selector ".question--current", wait: 5
      assert_selector ".design-picker", count: 0
      assert_no_overflow
      capture("#{design}-game-mobile")
      click_on "Stop the game"
      click_on "Stop game"
      assert_selector ".design-home__heading"

      viewport(1440, 1000)
      visit root_path
      assert_no_overflow
      capture("#{design}-home-desktop")
      visit topics_path
      assert_selector ".topic-card", count: Topic::ALL.size
      assert_no_overflow
      capture("#{design}-topics-desktop")
    end
  end

  test "the switcher persists through Turbo navigation, original is recoverable, and small screens fit" do
    viewport(320, 740)
    visit root_path(design: "sprint")
    assert_no_overflow
    find(".design-picker summary").click
    click_on "Bunch", exact: false
    assert_selector "html[data-design=bunch]"
    assert_no_overflow
    within(".design-navigation") { click_on "Stats" }
    assert_selector "h1", text: "Your stats"
    assert_selector "html[data-design=bunch]"
    assert_no_overflow
    find(".design-picker summary").click
    click_on "Original", exact: false
    assert_selector "html[data-design=original]"
    assert_selector ".site-footer__start"
  end

  private
    def viewport(width, height)
      # Chrome's desktop minimum window width is larger than a small phone. Emulate the actual viewport
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: width < 700)
    end

    def assert_no_overflow
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page scrolls sideways"
    end

    def capture(name)
      page.save_screenshot("/tmp/matheminute-design-review/#{name}.png")
    end
end
