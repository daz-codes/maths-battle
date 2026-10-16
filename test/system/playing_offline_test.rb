require "application_system_test_case"

class PlayingOfflineTest < ApplicationSystemTestCase
  setup do
    @user = users(:ada)
    sign_in @user
  end

  teardown { go_online }

  test "a game finished offline is kept on the device, then uploaded once back online" do
    click_on "Play"
    assert_selector ".question", text: "×", wait: 5
    end_game_in(3_000)
    5.times { answer_question }

    go_offline
    assert_selector ".offline-result", text: "saved on this device", wait: 8
    assert_equal 1, unsent_games, "kept for later"
    assert_equal 0, @user.attempts.count

    go_online
    assert_difference -> { @user.attempts.count }, 1 do
      visit root_path
      assert_selector ".nudge", text: "Your streak is safe for today", wait: 8
    end
    assert_equal 0, unsent_games
    assert_equal 1, @user.reload.current_streak
  end

  test "uploading again doesn't save the game twice" do
    page.execute_script(<<~JS)
      localStorage.setItem("matheminute:unsent-games", JSON.stringify([
        { client_id: "same-game", played_at: new Date().toISOString(), topic: "times_tables",
          results: [ { a: 2, b: 3, given: 6, ms: 900 } ] }
      ]))
    JS
    visit root_path
    visit stats_path
    assert_selector "h1", text: "Your stats"

    page.execute_script(<<~JS)
      localStorage.setItem("matheminute:unsent-games", JSON.stringify([
        { client_id: "same-game", played_at: new Date().toISOString(), topic: "times_tables",
          results: [ { a: 2, b: 3, given: 6, ms: 900 } ] }
      ]))
    JS
    visit root_path
    sleep 1
    assert_equal 1, @user.attempts.where(client_id: "same-game").count
  end

  test "an offline copy of the game page uses a spare question set rather than repeating one" do
    chosen = page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      import("lib/offline_games").then(({ chooseQuestionSet }) => {
        localStorage.clear()
        const sets = [ { id: "page", questions: [] }, { id: "spare-1", questions: [] }, { id: "spare-2", questions: [] } ]
        // The same page again, as it would come from the offline copy
        done([ chooseQuestionSet(sets).id, chooseQuestionSet(sets).id, chooseQuestionSet(sets).id ])
      })
    JS

    assert_equal %w[ page spare-1 spare-2 ], chosen
  end

  private
    def end_game_in(ms)
      page.execute_script(<<~JS)
        const test = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("[data-controller=test]"), "test")
        test.endsAt = performance.now() + #{ms}
        clearTimeout(test.endTimer)
      JS
    end

    def answer_question
      a, b = find(".question").text.split(" × ").map(&:to_i)
      find("body").send_keys((a * b).to_s)
    end

    def unsent_games
      page.evaluate_script(%(JSON.parse(localStorage.getItem("matheminute:unsent-games") || "[]").length))
    end

    def go_offline
      page.driver.browser.network_conditions = { offline: true, latency: 0, throughput: 0 }
    end

    def go_online
      page.driver.browser.network_conditions = { offline: false, latency: 0, throughput: 0 }
    end
end
