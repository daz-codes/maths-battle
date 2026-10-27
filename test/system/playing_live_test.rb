require "application_system_test_case"

class PlayingLiveTest < ApplicationSystemTestCase
  # Shortens the minute once the game's running, so the test needn't wait for it
  def shorten_the_minute
    page.execute_script(<<~JS)
      const waitForStart = setInterval(() => {
        const element = document.querySelector("[data-controller=test]")
        const test = element && window.Stimulus.getControllerForElementAndIdentifier(element, "test")
        if (test?.state === "running") { test.endsAt = performance.now() + 1000; clearInterval(waitForStart) }
      }, 10)
    JS
  end

  def answer_right
    a, b = find(".question--current").text.split(" × ").map(&:to_i)
    find("body").send_keys((a * b).to_s)
  end

  test "a lobby from a link, a Power game starting together, and each other's gems as they play" do
    users(:ada).update!(name: "Ada")
    sign_in users(:ada)
    visit groups_path
    click_on "Play Live"
    assert_selector "h1", text: "Live game"
    code = LiveGame.last.code

    using_session :zara do
      visit live_game_path(code)
      fill_in "What should we call you?", with: "Zara"
      click_on "Join the game"
      assert_text "Waiting for Ada to start…"
    end

    assert_selector "#live-players", text: "Zara", wait: 5
    click_on "Power"
    assert_selector "#live-mode", text: "Power mode"
    using_session(:zara) { assert_selector "#live-mode", text: "Power mode", wait: 5 }
    click_on "Start"
    assert_selector ".test__rival", text: "Zara 0"

    using_session :zara do
      assert_selector ".test__rival", text: "Ada 0", wait: 5
      assert_selector ".question", text: "×", wait: 10
      2.times { |answered| answer_right; assert_selector "[data-test-target=right]", text: /#{answered + 1}/ }
    end

    assert_selector ".test__rival.test__rival--ahead", text: "Zara 60", wait: 5
    3.times { |answered| answer_right; assert_selector "[data-test-target=right]", text: /#{answered + 1}/ }
    assert_selector ".test__rival.test__rival--behind", text: "Zara 60"
    assert_selector ".test__score", text: "90"
    using_session(:zara) { assert_selector ".test__rival.test__rival--ahead", text: "Ada 90", wait: 5 }

    shorten_the_minute
    using_session(:zara) { shorten_the_minute }

    assert_selector ".banner", text: "You came", wait: 15
    using_session :zara do
      assert_selector ".banner", text: "You came", wait: 15
      assert_selector "#live-podium .leaderboard__row", text: /Ada.*90.*3 right/m, wait: 5
      assert_selector "#live-podium .leaderboard__row", text: /Zara.*60.*2 right/m
    end
  end

  test "a Power game's boxes come at 15 seconds, and a Freeze stops the player ahead's keypad, with news for both" do
    ada = users(:ada)
    ada.update!(name: "Ada")
    game = LiveGame.make(host: ada, topic: TimesTables, level: 1)
    game.update!(mode: "power")
    sign_in ada
    visit live_game_path(game.code)

    using_session :zara do
      visit live_game_path(game.code)
      fill_in "What should we call you?", with: "Zara"
      click_on "Join the game"
      assert_text "Waiting for Ada to start…"
    end

    assert_selector "#live-players", text: "Zara", wait: 5
    click_on "Start"
    assert_selector ".question--current", text: "×", wait: 10
    2.times { |answered| answer_right; assert_selector "[data-test-target=right]", text: /#{answered + 1}/ }

    # Ada leads, so her box could be a Shield, which would block it
    assert_selector ".test__power:not([hidden])", wait: 20
    game.player_for(ada).update!(power_up: nil)

    using_session :zara do
      assert_selector ".test__power:not([hidden])", wait: 5
      game.player_for(User.find_by(name: "Zara")).update!(power_up: "freeze")
      find(".test__power").click
      assert_selector ".test__power-news", text: "You froze Ada!", wait: 5
    end

    assert_selector ".test.test--freeze", wait: 5
    assert_selector ".test__power-news", text: "Zara froze you!"
    assert_no_selector ".test.test--freeze", wait: 5
  end
end
