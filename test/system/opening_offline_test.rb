require "application_system_test_case"

# Chrome's offline mode in tests doesn't cut off the service worker itself, so these check what it
# stores for offline use, and that signing out clears it, rather than browsing with no network
class OpeningOfflineTest < ApplicationSystemTestCase
  setup do
    sign_in users(:ada)
    wait_for_service_worker
  end

  test "the home, game and stats pages are kept for offline use" do
    visit times_tables_path
    assert_selector ".question", text: "×", wait: 5
    visit stats_path
    visit root_path

    assert_equal [ "/", "/stats", "/times-tables" ], kept_pages.sort
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
        caches.open("matheminute-pages-v1")
          .then((cache) => cache.keys())
          .then((requests) => done(requests.map((request) => new URL(request.url).pathname)))
      JS
    end
end
