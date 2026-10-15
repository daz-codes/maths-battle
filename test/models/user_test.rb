require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  test "usernames are stored lowercase and stripped, so sign in isn't case sensitive" do
    user = User.create!(username: "  Charlie_9 ", password: "secret")
    assert_equal "charlie_9", user.username
    assert_equal user, User.authenticate_by(username: "CHARLIE_9", password: "secret")
  end

  test "usernames must be unique and simple" do
    assert_not User.new(username: "ADA", password: "secret").valid?
    assert_not User.new(username: "has space", password: "secret").valid?
    assert_not User.new(username: "ab", password: "secret").valid?
  end

  test "first practice starts a streak" do
    @user.record_practice!(Date.new(2026, 10, 15))
    assert_equal 1, @user.current_streak
    assert_equal 1, @user.longest_streak
    assert_equal Date.new(2026, 10, 15), @user.last_practised_on
  end

  test "practising twice in a day doesn't change the streak" do
    @user.record_practice!(Date.new(2026, 10, 15))
    @user.record_practice!(Date.new(2026, 10, 15))
    assert_equal 1, @user.current_streak
  end

  test "practising on consecutive days grows the streak" do
    @user.record_practice!(Date.new(2026, 10, 14))
    @user.record_practice!(Date.new(2026, 10, 15))
    @user.record_practice!(Date.new(2026, 10, 16))
    assert_equal 3, @user.current_streak
    assert_equal 3, @user.longest_streak
  end

  test "missing a day restarts the streak but keeps the longest" do
    @user.update!(current_streak: 5, longest_streak: 5, last_practised_on: Date.new(2026, 10, 13))
    @user.record_practice!(Date.new(2026, 10, 15))
    assert_equal 1, @user.current_streak
    assert_equal 5, @user.longest_streak
  end

  test "the live streak drops to zero once a whole day is missed" do
    @user.update!(current_streak: 4, last_practised_on: Date.new(2026, 10, 14))

    travel_to Time.zone.local(2026, 10, 15, 12) do
      assert_equal 4, @user.streak
      assert @user.streak_at_risk?
      assert_not @user.practised_today?
    end

    travel_to Time.zone.local(2026, 10, 16, 12) do
      assert_equal 0, @user.streak
      assert_not @user.streak_at_risk?
    end
  end

  test "today is worked out in the user's time zone" do
    # 11pm on the 14th in New York is already the 15th in London
    travel_to Time.utc(2026, 10, 15, 3) do
      assert_equal Date.new(2026, 10, 15), @user.today

      @user.time_zone = "Eastern Time (US & Canada)"
      assert_equal Date.new(2026, 10, 14), @user.today
    end
  end

  test "practice just after midnight counts for the new day" do
    @user.record_practice!(Date.new(2026, 10, 14))

    travel_to Time.zone.local(2026, 10, 15, 0, 5) do
      @user.record_practice!
    end
    assert_equal 2, @user.current_streak
  end

  test "high score only goes up" do
    assert @user.record_score!(10)
    assert_not @user.record_score!(8)
    assert_not @user.record_score!(10)
    assert_equal 10, @user.reload.high_score
  end
end

class UserGuestTest < ActiveSupport::TestCase
  test "guests have no username or password" do
    guest = User.create_guest!
    assert guest.guest?
    assert_nil guest.display_name
  end

  test "registering a guest needs a name, username and password" do
    guest = User.create_guest!

    assert_not guest.register(name: "", username: "", password: "")
    assert_equal %i[ name password username ], guest.errors.attribute_names.sort

    assert guest.register(name: "Zara", username: "Zara_B", password: "1234")
    assert_not guest.reload.guest?
    assert_equal "Zara", guest.display_name
  end

  test "display name falls back to username" do
    assert_equal "ada", users(:ada).display_name
    users(:ada).name = "Ada"
    assert_equal "Ada", users(:ada).display_name
  end
end
