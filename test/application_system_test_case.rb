require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 400, 800 ] do |options|
    # Chrome's save-password and leaked-password bubbles steal keystrokes after signing in
    options.add_preference("credentials_enable_service", false)
    options.add_preference("profile.password_manager_enabled", false)
    options.add_preference("profile.password_manager_leak_detection", false)
    options.add_argument("--disable-features=PasswordLeakDetection,PasswordManagerOnboarding")
  end

  def sign_in(user)
    visit new_session_path
    fill_in "Username", with: user.username
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector ".streak"
  end
end
