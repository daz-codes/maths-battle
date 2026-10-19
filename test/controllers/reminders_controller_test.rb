require "test_helper"

class RemindersControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:ada) }

  def turn_on(minute: 17 * 60, endpoint: PUSH_ENDPOINT)
    keys = push_keys(endpoint: endpoint)
    patch reminder_path, params: { minute: minute, subscription: { endpoint: keys[:endpoint], keys: keys.slice(:p256dh, :auth) } }, as: :json
  end

  test "the settings page has the reminder, with the time picked and the key browsers subscribe with" do
    sign_in_as @user
    @user.update!(reminder_minute: 18 * 60 + 30)
    get edit_profile_path

    assert_select ".reminder[data-reminder-on-value=true][data-reminder-key-value=?]", PushSubscription.public_key
    assert_select ".reminder select option[selected][value=1110]", text: "6:30pm"
    assert_select ".reminder select option", User::REMINDER_MINUTES.size
  end

  test "turning on saves this device and the time; turning off stops them everywhere" do
    sign_in_as @user
    turn_on
    assert_response :no_content
    assert_equal [ 17 * 60, [ PUSH_ENDPOINT ] ], [ @user.reload.reminder_minute, @user.push_subscriptions.pluck(:endpoint) ]

    delete reminder_path, as: :json
    assert_response :no_content
    assert_nil @user.reload.reminder_minute
    assert_empty @user.push_subscriptions
  end

  test "anything but a half hour or a browser's push service is refused" do
    sign_in_as @user
    turn_on(minute: 17 * 60 + 1)
    assert_response :unprocessable_entity
    turn_on(endpoint: "https://169.254.169.254/latest")
    assert_response :unprocessable_entity
    assert_empty PushSubscription.all
  end

  test "a visitor turning them on gets a guest account to keep them" do
    assert_difference -> { User.count } do
      turn_on
    end
    assert User.last.guest?
    assert User.last.reminders_on?
  end
end
