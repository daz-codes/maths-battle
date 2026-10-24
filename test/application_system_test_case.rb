require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # One at a time: with a browser and the app's server per worker, SQLite gives "database is locked" under the load
  parallelize(workers: 1)

  driven_by :selenium, using: :headless_chrome, screen_size: [ 400, 800 ] do |options|
    # Chrome's save-password and leaked-password bubbles steal keystrokes after signing in
    options.add_preference("credentials_enable_service", false)
    options.add_preference("profile.password_manager_enabled", false)
    options.add_preference("profile.password_manager_leak_detection", false)
    options.add_argument("--disable-features=PasswordLeakDetection,PasswordManagerOnboarding")
    # Games tick, buzz and play fanfares (lib/feedback.js): not out loud while the tests run
    options.add_argument("--mute-audio")
  end

  setup do
    # Back to the usual size, as a test can make the window smaller for its own checks
    page.current_window.resize_to(400, 800)
    visit root_path
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      navigator.serviceWorker.ready.then(async () => {
        localStorage.clear()
        const keys = await caches.keys()
        await Promise.all(keys.filter(key => key.startsWith('matheminute-pages') || key.startsWith('matheminute-player')).map(key => caches.delete(key)))
        done()
      })
    JS
    choose_topic
  end

  # A new player picks a topic before the home page shows
  def choose_topic(name = "Times tables")
    assert_selector "h1", text: "What do you want to practise?"
    click_on name
    assert_selector ".streak"
  end

  def game_for_upload(client_id:)
    owner = find('meta[name="player-key"]', visible: false)["content"]
    results = answers([ 2, 3, 6 ])
    { client_id: client_id, played_at: Time.current.iso8601, topic: "times_tables", level: 1, player_key: owner, results: results,
      ticket: Attempt::GameTicket.issue(owner: owner, topic: "times_tables", level: 1, id: client_id, questions: results) }
  end

  def queue_game(*games)
    page.execute_script(<<~JS, games.as_json)
      const key = 'matheminute:unsent-games:' + document.querySelector('meta[name="player-key"]').content
      localStorage.setItem(key, JSON.stringify(arguments[0]))
    JS
  end

  def sign_in(user)
    visit new_session_path
    fill_in "Username", with: user.username
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector ".streak"
  end
end
