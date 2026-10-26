require "application_system_test_case"

# Chrome's offline mode in tests doesn't cut off the service worker itself, so these check what it
# stores for offline use, and that signing out clears it, rather than browsing with no network
class OpeningOfflineTest < ApplicationSystemTestCase
  setup do
    sign_in users(:ada)
    wait_for_service_worker
  end

  test "the home, practice, game and stats pages are kept for offline use" do
    visit play_path("times-tables")
    assert_selector ".question", text: "×", wait: 5
    visit stats_path
    visit practice_path
    visit root_path

    assert_equal [ "/", "/play/times-tables", "/practice", "/stats" ], kept_pages.sort
  end

  test "each level's game page is kept separately" do
    unlock(users(:ada), TimesTables, 2)
    visit play_path("times-tables", level: 1)
    assert_selector ".question", text: "×", wait: 5
    visit play_path("times-tables", level: 2)
    assert_selector ".question", text: "×", wait: 5
    visit root_path

    assert_includes kept_pages, "/play/times-tables?level=1"
    assert_includes kept_pages, "/play/times-tables?level=2"
  end

  test "signing out forgets this player's pages and unsent games" do
    visit stats_path
    page.execute_script(%(localStorage.setItem("matheminute:unsent-games", "[{}]")))
    assert_includes kept_pages, "/stats"

    visit edit_profile_path
    click_on "Sign out"
    assert_selector "h1", text: "Welcome back!"

    assert_empty kept_pages
    assert_nil page.evaluate_script(%(localStorage.getItem("matheminute:unsent-games")))
  end

  test "signing in as someone else forgets the last player's unsent games and pages" do
    visit edit_profile_path
    click_on "Sign out"
    assert_selector "h1", text: "Welcome back!"
    visit stats_path
    assert_includes kept_pages, "/stats"

    # A game left over from whoever played last, still waiting when someone else signs in
    visit new_session_path
    page.execute_script(<<~JS)
      localStorage.setItem("matheminute:unsent-games", JSON.stringify([
        { client_id: "last-player", played_at: new Date().toISOString(), topic: "times_tables", level: 1,
          results: [ { a: 2, b: 3, given: 6, ms: 900 } ] }
      ]))
    JS
    fill_in "Username", with: "bob"
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector ".streak"

    assert_nil page.evaluate_script(%(localStorage.getItem("matheminute:unsent-games")))
    assert_not Attempt.exists?(client_id: "last-player")
    assert_not_includes kept_pages, "/stats"
  end

  test "switching directly to another account clears owned games and the previous cache" do
    visit stats_path
    owner = find('meta[name="player-key"]', visible: false)["content"]
    game = game_for_upload(client_id: "adas-pending-game")
    visit new_session_path
    queue_game(game)
    fill_in "Username", with: "bob"
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector ".ui-header__hello", text: "Hi bob!"
    assert_not Attempt.exists?(client_id: "adas-pending-game")
    assert_nil page.evaluate_script("localStorage.getItem(arguments[0])", "matheminute:unsent-games:#{owner}")
    cache_names = page.evaluate_async_script("caches.keys().then(arguments[0])")
    assert_not_includes cache_names, "matheminute-pages-v4-#{owner}"
  end

  test "an old tab refreshes when another tab switches accounts" do
    other = open_new_window
    within_window(other) do
      visit new_session_path
      fill_in "Username", with: "bob"
      fill_in "Password", with: "password"
      click_button "Sign in"
      assert_selector ".ui-header__hello", text: "Hi bob!"
    end
    assert_selector ".ui-header__hello", text: "Hi bob!", wait: 8
  ensure
    other&.close
  end

  private
    def wait_for_service_worker
      page.evaluate_async_script(<<~JS)
        const done = arguments[0]
        navigator.serviceWorker.ready.then(() => {
          if (navigator.serviceWorker.controller) return done()
          navigator.serviceWorker.addEventListener("controllerchange", () => done())
        })
      JS
    end

    def kept_pages
      sleep 0.3 # pages are stored just after they load
      page.evaluate_async_script(<<~JS)
        const done = arguments[0]
        caches.open("matheminute-pages-v4-" + document.querySelector('meta[name="player-key"]').content)
          .then((cache) => cache.keys())
          .then((requests) => done(requests.map((request) => { const url = new URL(request.url); return url.pathname + url.search })))
      JS
    end
end
