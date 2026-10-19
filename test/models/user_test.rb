require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup { @user = users(:ada) }

  test "usernames are stored lowercase and stripped, so sign in isn't case sensitive" do
    user = User.create!(username: "  Charlie_9 ", password: "a long secret phrase")
    assert_equal "charlie_9", user.username
    assert_equal user, User.authenticate_by(username: "CHARLIE_9", password: "a long secret phrase")
  end

  test "usernames must be unique and simple" do
    assert_not User.new(username: "ADA", password: "a long secret phrase").valid?
    assert_not User.new(username: "has space", password: "a long secret phrase").valid?
    assert_not User.new(username: "ab", password: "a long secret phrase").valid?
  end

  def play_on(date, **options)
    travel_to(date.in_time_zone.change(hour: 12)) { play_daily_challenge(@user, **options) }
  end

  def day(n) = Date.new(2026, 11, n)

  test "a first daily challenge starts a streak" do
    play_on day(15)
    assert_equal [ 1, 1, day(15) ], [ @user.current_streak, @user.longest_streak, @user.last_practised_on ]
  end

  test "another topic's daily challenge the same day doesn't change the streak" do
    play_on day(15)
    play_on day(15), topic: Equations
    assert_equal 1, @user.current_streak
  end

  test "daily challenges on consecutive days grow the streak" do
    play_on day(14)
    play_on day(15)
    play_on day(16)
    assert_equal 3, @user.current_streak
    assert_equal 3, @user.longest_streak
  end

  test "missing a day restarts the streak but keeps the longest" do
    [ 9, 10, 11, 12, 13 ].each { play_on day(_1) }
    play_on day(15)
    assert_equal 1, @user.current_streak
    assert_equal 5, @user.longest_streak
  end

  test "only the daily challenge keeps the streak, even a short one; practice, reviews and lessons don't" do
    travel_to(day(15).in_time_zone.change(hour: 12)) do
      Attempt.record!(user: @user, results: answers(*right_answers(20)))
      @user.complete_lesson!(TimesTables, 1)
      assert_equal 0, @user.reload.current_streak
      assert_not @user.practised_today?

      play_daily_challenge(@user, answered: 1)
      assert_equal 1, @user.reload.current_streak
      assert @user.practised_today?
    end
  end

  test "before the daily challenge did, a game long enough or a lesson kept the streak, and those days still count" do
    before = User::Streakable::DAILY_CHALLENGE_STREAKS_FROM
    travel_to((before - 3).in_time_zone.change(hour: 12)) { Attempt.record!(user: @user, results: answers(*right_answers(4))) }
    travel_to((before - 2).in_time_zone.change(hour: 12)) { Attempt.record!(user: @user, results: answers(*right_answers(5))) }
    travel_to((before - 1).in_time_zone.change(hour: 12)) { @user.complete_lesson!(TimesTables, 1) }
    travel_to(before.in_time_zone.change(hour: 12)) { play_daily_challenge(@user) }

    assert_equal 3, @user.reload.current_streak, "a short game never counted"
  end

  test "a game played offline yesterday still counts when it arrives today" do
    play_on day(14)
    play_on day(16)
    assert_equal 1, @user.current_streak, "the 15th looks missed"

    # The game from the 15th was played offline and uploads on the 16th
    play_on day(16), played_at: day(15).in_time_zone.change(hour: 18).iso8601
    assert_equal 3, @user.reload.current_streak
    assert_equal day(16), @user.last_practised_on
  end

  test "the live streak drops to zero once a whole day is missed" do
    @user.update!(current_streak: 4, last_practised_on: Date.new(2026, 10, 14), streak_kept_on: Date.new(2026, 10, 14))

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

  test "takes the time zone the device names, ignoring ones it doesn't know" do
    @user.update_time_zone("America/Los_Angeles")
    assert_equal "America/Los_Angeles", @user.reload.time_zone

    [ "", "Nowhere/Special", nil, 5 ].each { |zone| @user.update_time_zone(zone) }
    assert_equal "America/Los_Angeles", @user.reload.time_zone
    assert_not User.new(time_zone: "Nowhere/Special").valid?
  end

  test "a daily challenge just after midnight counts for the new day" do
    play_on day(14)

    travel_to(Time.zone.local(2026, 11, 15, 0, 5)) { play_daily_challenge(@user) }
    assert_equal 2, @user.current_streak
  end

  test "best score is the highest in a topic" do
    Attempt.record!(user: @user, results: answers(*right_answers(10)))
    Attempt.record!(user: @user, results: answers(*right_answers(8)))
    assert_equal 10, @user.best_score(TimesTables, 1)
  end
end

class UserGuestTest < ActiveSupport::TestCase
  test "new passwords must be at least fifteen characters" do
    guest = User.create_guest!
    assert_not guest.register(name: "Zara", username: "zara_b", password: "1234")
    assert guest.errors.added?(:password, :too_short, count: User::MIN_PASSWORD_LENGTH)
  end

  test "passwords cannot exceed bcrypt's byte limit even with fewer than seventy two characters" do
    guest = User.create_guest!
    assert_not guest.register(name: "Zara", username: "zara_b", password: "é" * 37)
    assert guest.errors.added?(:password, :password_too_long)
  end

  test "guests have no username or password" do
    guest = User.create_guest!
    assert guest.guest?
    assert_nil guest.display_name
  end

  test "registering a guest needs a name, username and password" do
    guest = User.create_guest!

    assert_not guest.register(name: "", username: "", password: "")
    assert_equal %i[ name password username ], guest.errors.attribute_names.sort

    assert guest.register(name: "Zara", username: "Zara_B", password: "a long secret phrase")
    assert_not guest.reload.guest?
    assert_equal "Zara", guest.display_name
  end

  test "display name falls back to username" do
    assert_equal "ada", users(:ada).display_name
    users(:ada).name = "Ada"
    assert_equal "Ada", users(:ada).display_name
  end
end
