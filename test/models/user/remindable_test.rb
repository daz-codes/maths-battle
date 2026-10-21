require "test_helper"

class User::RemindableTest < ActiveSupport::TestCase
  setup do
    @user = users(:ada)
    @user.turn_on_reminders!(17 * 60, **push_keys)
  end

  def london(day, hour, minute = 0) = ActiveSupport::TimeZone["London"].local(2026, 11, day, hour, minute)

  test "turning reminders on keeps the time and this device; another device is added" do
    @user.turn_on_reminders!(18 * 60 + 30, **push_keys(endpoint: "https://web.push.apple.com/device-2"))

    assert_equal 18 * 60 + 30, @user.reload.reminder_minute
    assert_equal [ PUSH_ENDPOINT, "https://web.push.apple.com/device-2" ], @user.push_subscriptions.order(:id).pluck(:endpoint)
  end

  test "a device moves to whoever turned reminders on there last" do
    users(:bob).turn_on_reminders!(8 * 60, **push_keys)
    assert_empty @user.push_subscriptions.reload
    assert_equal 1, users(:bob).push_subscriptions.count
  end

  test "only half hours in the day, and only the browsers' own push services" do
    assert_raises(ActiveRecord::RecordInvalid) { @user.turn_on_reminders!(17 * 60 + 7, **push_keys) }
    assert_raises(ActiveRecord::RecordInvalid) { @user.turn_on_reminders!(3 * 60, **push_keys) }
    assert_raises(ActiveRecord::RecordInvalid) { @user.turn_on_reminders!(17 * 60, **push_keys(endpoint: "https://example.com/push")) }
    assert_raises(ActiveRecord::RecordInvalid) { @user.turn_on_reminders!(17 * 60, **push_keys(endpoint: "http://fcm.googleapis.com/x")) }
  end

  test "due from the time picked, in the player's own time zone, for a couple of hours" do
    assert_not @user.reminder_due?(london(10, 16, 59))
    assert @user.reminder_due?(london(10, 17))
    assert @user.reminder_due?(london(10, 19))
    assert_not @user.reminder_due?(london(10, 19, 15)), "too late to be any use"

    @user.update!(time_zone: "America/New_York")
    assert_not @user.reminder_due?(london(10, 17))
    assert @user.reminder_due?(ActiveSupport::TimeZone["America/New_York"].local(2026, 11, 10, 17, 5))
  end

  test "not once a game has been played today" do
    travel_to(london(10, 12)) { play_daily_challenge(@user) }
    assert_not @user.reminder_due?(london(10, 17))
  end

  test "once a day: sent to each device, then not again until tomorrow" do
    @user.turn_on_reminders!(17 * 60, **push_keys(endpoint: "https://web.push.apple.com/device-2"))

    sent = travel_to(london(10, 17, 5)) { pushes_sent { User.send_due_reminders } }
    assert_equal [ PUSH_ENDPOINT, "https://web.push.apple.com/device-2" ], sent.map { _1[:endpoint] }.sort
    assert_equal({ title: "⭐ Time for a minute of maths", body: "Play a game to start a streak!", url: "/" }, sent.first[:message])

    assert_empty travel_to(london(10, 17, 20)) { pushes_sent { User.send_due_reminders } }
    assert_equal 2, travel_to(london(11, 17, 5)) { pushes_sent { User.send_due_reminders } }.size
  end

  test "names the streak that's waiting" do
    travel_to(london(9, 12)) { play_daily_challenge(@user) }

    sent = travel_to(london(10, 17, 5)) { pushes_sent { User.send_due_reminders } }
    assert_equal "🔥 Your 1 day streak is waiting", sent.first[:message][:title]
  end

  test "players with reminders off, or no device for them, get none" do
    users(:bob).update!(reminder_minute: 17 * 60)
    @user.turn_off_reminders!

    assert_empty travel_to(london(10, 17, 5)) { pushes_sent { User.send_due_reminders } }
    assert_nil @user.reload.reminder_minute
    assert_empty PushSubscription.all
  end

  test "a device that's unsubscribed is forgotten; other failures keep it for next time" do
    travel_to(london(10, 17, 5)) { pushes_sent(failing_with: push_response_error(WebPush::PushServiceError)) { User.send_due_reminders } }
    assert_equal 1, @user.push_subscriptions.count

    travel_to(london(11, 17, 5)) { pushes_sent(failing_with: push_response_error(WebPush::ExpiredSubscription)) { User.send_due_reminders } }
    assert_empty @user.push_subscriptions.reload
  end

  test "sends the server's keys, and doesn't keep a reminder for hours" do
    push = travel_to(london(10, 17, 5)) { pushes_sent { User.send_due_reminders } }.first

    assert_equal PushSubscription.public_key, push.dig(:vapid, :public_key)
    assert push.dig(:vapid, :private_key).present?
    assert_equal 6.hours.to_i, push[:ttl]
  end

  test "a group challenge waiting is in the reminder, and is reason enough for one once a game's been played" do
    group = users(:bob).owned_groups.create!(name: "Class 4B")
    group.join(@user)
    challenge = travel_to(london(10, 9)) { group.challenges.create!(topic: "times_tables", level: 2) }

    sent = travel_to(london(10, 17, 5)) { pushes_sent { User.send_due_reminders } }
    assert_equal "Play a game to start a streak! Class 4B's challenge is waiting too.", sent.first[:message][:body]

    travel_to(london(11, 12)) { play_daily_challenge(@user) }
    sent = travel_to(london(11, 17, 5)) { pushes_sent { User.send_due_reminders } }
    assert_equal [ "🏆 Class 4B's challenge is waiting", "/groups/#{group.id}/challenges/#{challenge.id}" ], sent.first[:message].values_at(:title, :url)
  end
end
