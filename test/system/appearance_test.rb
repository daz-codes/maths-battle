require "application_system_test_case"

class AppearanceTest < ApplicationSystemTestCase
  setup do
    FileUtils.mkdir_p("/tmp/matheminute-appearance")
    @user = users(:ada)
    @user.update!(name: "Ada")
    @attempt = record_tables_game(@user, answers(*right_answers(18), ms: 1000))
    sign_in(@user)
  end

  test "light and dark share the Arcade layout across the app at phone and desktop sizes" do
    %w[ light dark ].each do |theme|
      viewport(390, 844)
      choose_appearance(theme)
      visit root_path
      assert_selector "html[data-theme=#{theme}]"
      assert_selector ".ui-home__heading"
      assert_no_overflow
      capture("#{theme}-home-mobile")

      within("main") { click_on "Practice", exact: false }
      assert_selector ".current-topic__name", text: "Times tables"
      assert_no_overflow
      capture("#{theme}-practice-mobile")

      visit challenge_path
      assert_selector "h1", text: /Daily/
      assert_no_overflow
      capture("#{theme}-daily-mobile")
      visit groups_path
      assert_selector "h1", text: "Compete"
      assert_no_overflow
      capture("#{theme}-compete-mobile")
      visit attempt_path(@attempt)
      assert_selector ".result"
      assert_no_overflow
      capture("#{theme}-results-mobile")
      visit awards_path
      assert_selector "h1"
      assert_no_overflow
      capture("#{theme}-awards-mobile")

      visit play_path("times-tables")
      assert_selector ".question--current", text: "×", wait: 5
      find("body").send_keys(page.evaluate_script('window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller=test]"), "test").current.answer'))
      assert_selector ".test__right", text: "1"
      assert_no_selector ".design-picker, html[data-design]"
      assert_no_overflow
      capture("#{theme}-game-mobile")
      find(".test__stop").click
      click_on "Stop game"
      assert_selector ".ui-home__heading"

      viewport(1440, 1000)
      visit root_path
      assert_no_overflow
      capture("#{theme}-home-desktop")
      visit topics_path
      assert_selector ".topic-card", count: Topic::ALL.size
      assert_no_overflow
      capture("#{theme}-topics-desktop")
    end
  end

  test "system mode follows the device while explicit preferences persist through navigation" do
    viewport(320, 740)
    choose_appearance("system")
    emulate_scheme("dark")
    assert_background("#10121b")
    emulate_scheme("light")
    assert_background("#f3f6fb")

    choose_appearance("light")
    emulate_scheme("dark")
    assert_background("#f3f6fb")
    assert_browser_colours("#f3f6fb")
    visit root_path
    within(".ui-navigation") { click_on "Stats" }
    assert_selector "h1", text: "Your stats"
    assert_selector "html[data-theme=light]"
    assert_background("#f3f6fb")

    choose_appearance("dark")
    emulate_scheme("light")
    assert_background("#10121b")
    assert_browser_colours("#10121b")
    visit root_path
    assert_selector "html[data-theme=dark]"
    assert_no_selector ".design-picker, html[data-design]"
  end

  test "longer questions fit both appearances on a small phone" do
    %w[ light dark ].each do |theme|
      viewport(320, 740)
      choose_appearance(theme)
      visit root_path
      [ "fractions", "functions", "simultaneous-equations" ].each do |topic|
        visit play_path(topic)
        assert_selector ".test"
        assert_selector ".keypad__key--submit", text: "Check answer"
        assert_no_overflow
        assert page.evaluate_script(<<~JS), "the keypad must remain in the viewport"
          (() => {
            const box = document.querySelector('.keypad').getBoundingClientRect()
            return box.top >= 0 && box.bottom <= window.innerHeight + 1
          })()
        JS
        find(".test__stop").click
        click_on "Stop game"
        assert_selector ".ui-home__heading"
      end
    end
  end

  test "settings and populated competition screens fit a small phone" do
    group = @user.owned_groups.create!(name: "Class 4B")
    group.join(users(:bob))
    challenge = group.challenges.create!(topic: "times_tables", level: 2)
    Attempt.record!(user: users(:bob), topic: "times_tables", level: 2, mode: "group", round: challenge.round,
      results: answers(*right_answers(3)))
    live = LiveGame.make(host: @user, topic: TimesTables, level: 1)

    %w[ light dark ].each do |theme|
      viewport(320, 740)
      choose_appearance(theme)
      visit root_path
      [ edit_profile_path, group_path(group), group_challenge_path(group, challenge), live_game_path(live) ].each do |path|
        visit path
        assert_selector "main"
        assert_no_overflow
      end
      visit group_challenge_path(group, challenge)
      assert_selector ".leaderboard__name", text: "bob"
      capture("#{theme}-leaderboard-mobile")
    end
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  private
    def choose_appearance(theme)
      visit edit_profile_path
      within("fieldset", text: "Colours") { choose(theme == "system" ? "Same as device" : theme.capitalize) }
      assert_selector "html[data-theme=#{theme}]"
      page.document.synchronize do
        raise Capybara::ExpectationNotMet, "appearance was not saved" unless @user.reload.theme == theme
      end
    end

    def emulate_scheme(scheme)
      page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-color-scheme", value: scheme } ])
    end

    def assert_background(colour)
      assert_equal colour, page.evaluate_script("getComputedStyle(document.documentElement).getPropertyValue('--paper').trim()")
    end

    def assert_browser_colours(colour)
      assert_equal [ colour ], page.evaluate_script("Array.from(document.querySelectorAll('meta[name=theme-color]')).map(meta => meta.content)").uniq
    end

    def viewport(width, height)
      # Chrome's desktop minimum window width is larger than a small phone. Emulate the actual viewport
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: width < 700)
    end

    def assert_no_overflow
      assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page scrolls sideways"
    end

    def capture(name)
      page.execute_script("window.scrollTo(0, 0)")
      page.execute_script("document.getAnimations().filter(animation => Number.isFinite(animation.effect.getComputedTiming().endTime)).forEach(animation => animation.finish())")
      page.evaluate_async_script(<<~JS)
        const done = arguments[0]
        requestAnimationFrame(() => requestAnimationFrame(done))
      JS
      page.save_screenshot("/tmp/matheminute-appearance/#{name}.png")
    end
end
