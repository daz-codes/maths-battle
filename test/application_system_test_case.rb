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

  # The question showing, answered right ("7 × 8" types 56), or wrong
  def answer_question(right: true)
    text = find(".question--current").text
    a, op, b = text.split(" ")
    answer = right ? Ladder.answer(op == "×" ? "x" : "÷", a, b) : "1"
    answer = "0" if !right && Ladder.answer(op == "×" ? "x" : "÷", a, b) == "1"
    find("body").send_keys(answer)
    find("body").send_keys(:enter) unless right
    assert_selector ".answer--wrong" unless right
    assert_no_selector ".answer--wrong", wait: 2
  end

  # Ends the game in a second, so a test needn't wait the whole two minutes
  def shorten_the_game
    page.execute_script(<<~JS)
      const element = document.querySelector("[data-controller=test]")
      const test = window.Stimulus.getControllerForElementAndIdentifier(element, "test")
      test.endsAt = performance.now() + 1000
      test.scheduleEnd()
    JS
  end

  def sign_in(user)
    visit new_session_path
    fill_in "Username", with: user.username
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector ".ui-home__heading"
  end
end
