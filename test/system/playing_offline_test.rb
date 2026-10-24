require "application_system_test_case"

class PlayingOfflineTest < ApplicationSystemTestCase
  setup do
    @user = users(:ada)
    sign_in @user
  end

  teardown { go_online }

  test "a game finished offline is kept on the device, then uploaded once back online" do
    click_on "Practice"
    click_on "Play level 1"
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
      click_on "Practice"
      assert_selector ".levels__name", text: "Level 2", wait: 8 # the 5 right was a bronze
    end
    assert_equal 0, unsent_games
  end

  test "uploading again doesn't save the game twice" do
    game = game_for_upload(client_id: "same-game")
    queue_game(game)
    visit stats_path
    assert_selector "h1", text: "Your stats"
    assert_selector ".refused-games", visible: :all, text: "", wait: 5
    assert_equal 1, @user.attempts.where(client_id: "same-game").count

    queue_game(game)
    visit practice_path
    assert_selector ".stats dd", text: "1", wait: 5
    assert_equal 0, unsent_games
    assert_equal 1, @user.attempts.where(client_id: "same-game").count
  end

  test "a game the server refuses is dropped, and the player is told" do
    refused = game_for_upload(client_id: "refused")
    refused[:ticket] = "invalid"
    queue_game(refused, game_for_upload(client_id: "saved"))
    visit stats_path

    assert_selector ".refused-games", text: "Sorry, a game played offline couldn't be saved.", wait: 8
    assert_equal 0, unsent_games
    assert @user.attempts.exists?(client_id: "saved"), "the other game still counts"

    visit root_path
    assert_selector ".streak"
    assert_no_selector ".refused-games", visible: :all, text: /Sorry/
  end

  test "a failed device write offers retry instead of claiming an offline save" do
    click_on "Practice"
    click_on "Play level 1"
    assert_selector ".question", text: "×", wait: 5
    5.times { answer_question }
    page.execute_script(<<~JS)
      window.originalFetch = window.fetch
      window.fetch = () => Promise.reject(new Error('offline'))
      window.originalSetItem = Storage.prototype.setItem
      Storage.prototype.setItem = () => { throw new Error('QuotaExceededError') }
      const game = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector('[data-controller=test]'), 'test')
      game.finish()
    JS
    assert_selector ".test__status", text: "couldn't be saved on this device"
    assert_no_selector ".offline-result"
    page.execute_script("window.fetch = window.originalFetch; Storage.prototype.setItem = window.originalSetItem")
    click_button "Try saving again"
    assert_selector ".result__score", text: /\b5 right/, wait: 8
    assert_equal 1, @user.attempts.count
  end

  test "an offline copy of the game page uses a spare question set rather than repeating one" do
    chosen = page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      import("lib/offline_games").then(({ chooseQuestionSet }) => {
        localStorage.clear()
        const sets = [ { id: "page", questions: [] }, { id: "spare-1", questions: [] }, { id: "spare-2", questions: [] } ]
        // The same page again, as it would come from the offline copy
        done([ chooseQuestionSet(sets, "times_tables:1").id, chooseQuestionSet(sets, "times_tables:1").id, chooseQuestionSet(sets, "times_tables:1").id ])
      })
    JS

    assert_equal %w[ page spare-1 spare-2 ], chosen
  end

  test "an offline game only uses spares from the same topic and level" do
    chosen = page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      import("lib/offline_games").then(({ chooseQuestionSet }) => {
        localStorage.clear()
        chooseQuestionSet([ { id: "tables-1" }, { id: "tables-1-spare" } ], "times_tables:1")
        chooseQuestionSet([ { id: "equations-2" }, { id: "equations-2-spare" } ], "equations:2")
        chooseQuestionSet([ { id: "tables-3" }, { id: "tables-3-spare" } ], "times_tables:3")
        // Each offline copy again, now that its own set has been played
        done([
          chooseQuestionSet([ { id: "equations-2" } ], "equations:2").id,
          chooseQuestionSet([ { id: "tables-1" } ], "times_tables:1").id,
          chooseQuestionSet([ { id: "tables-3" } ], "times_tables:3").id
        ])
      })
    JS

    assert_equal %w[ equations-2-spare tables-1-spare tables-3-spare ], chosen
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
      a, b = find(".question--current").text.split(" × ").map(&:to_i)
      find("body").send_keys((a * b).to_s)
    end

    def unsent_games
      page.evaluate_script(%(JSON.parse(localStorage.getItem("matheminute:unsent-games:" + document.querySelector('meta[name="player-key"]').content) || "[]").length))
    end

    def go_offline
      # Chrome's network emulation does not stop an already running service worker's fetches.
      page.execute_script(<<~JS)
        window.beforeOfflineFetch = window.fetch
        window.fetch = (url, options) => options?.method === 'POST' && String(url).includes('/attempts')
          ? Promise.reject(new Error('offline')) : window.beforeOfflineFetch(url, options)
      JS
      page.driver.browser.network_conditions = { offline: true, latency: 0, throughput: 0 }
    end

    def go_online
      page.driver.browser.network_conditions = { offline: false, latency: 0, throughput: 0 }
      page.execute_script("if (window.beforeOfflineFetch) window.fetch = window.beforeOfflineFetch")
    end
end
