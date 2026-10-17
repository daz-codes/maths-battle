require "application_system_test_case"

class ComingBackToTheAppTest < ApplicationSystemTestCase
  setup do
    @user = users(:ada)
    sign_in @user
    assert_selector ".streak__number", text: "0"
  end

  test "the page reloads when the app comes back after a while, so the streak is current" do
    leave_the_app
    @user.update!(current_streak: 4, last_practised_on: @user.today, streak_kept_on: @user.today)
    come_back(after: 2.minutes)

    assert_selector ".streak__number", text: "4", wait: 5
  end

  test "a quick look away doesn't reload" do
    leave_the_app
    @user.update!(current_streak: 4, last_practised_on: @user.today, streak_kept_on: @user.today)
    come_back(after: 5.seconds)

    sleep 1
    assert_selector ".streak__number", text: "0"
  end

  private
    def leave_the_app
      set_hidden(true)
    end

    def come_back(after:)
      page.execute_script(<<~JS)
        const sync = window.Stimulus.getControllerForElementAndIdentifier(document.body, "sync")
        sync.hiddenAt = Date.now() - #{after.in_milliseconds}
      JS
      set_hidden(false)
    end

    def set_hidden(hidden)
      page.execute_script(<<~JS)
        Object.defineProperty(document, "hidden", { value: #{hidden}, configurable: true })
        document.dispatchEvent(new Event("visibilitychange"))
      JS
    end
end
