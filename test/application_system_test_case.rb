require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 400, 800 ]

  def sign_in(user)
    visit new_session_path
    fill_in "Username", with: user.username
    fill_in "Password", with: "password"
    click_on "Sign in"
    assert_selector ".streak"
  end
end
