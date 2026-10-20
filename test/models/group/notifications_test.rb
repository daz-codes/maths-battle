require "test_helper"

class Group::NotificationsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @owner, @bob = users(:ada), users(:bob)
    @group = @owner.owned_groups.create!(name: "Class 4B")
    @group.join(@bob)
    @bob.update!(name: "Bob")
    @owner.update!(name: "Ada")
  end

  def london(day, hour = 12) = ActiveSupport::TimeZone["London"].local(2026, 11, day, hour)

  def subscribe(user, endpoint: "https://fcm.googleapis.com/fcm/send/#{user.username}")
    user.turn_on_reminders!(17 * 60, **push_keys(endpoint: endpoint))
  end

  def play(user, challenge, right:, wrong: 0)
    results = Array.new(right) { { a: 2, b: 3, given: 6, ms: 1000 } } + Array.new(wrong) { { a: 2, b: 3, given: 7, ms: 1000 } }
    Attempt.record!(user: user, topic: "times_tables", level: 2, mode: "group", round: challenge.round, results: results)
  end

  def sent
    pushes_sent { perform_enqueued_jobs { yield } }
  end

  test "a new challenge tells the group's players, not the owner who set it" do
    subscribe(@owner)
    subscribe(@bob)
    pushes = travel_to(london(2)) { sent { @group.challenges.create!(topic: "times_tables", level: 2, daily: true) } }

    assert_equal [ "https://fcm.googleapis.com/fcm/send/bob" ], pushes.map { _1[:endpoint] }
    assert_equal "🏆 New challenge in Class 4B", pushes.first[:message][:title]
    assert_match "Times tables · Level 2 · new questions every day", pushes.first[:message][:body]
    assert_match %r{\A/groups/\d+/challenges/\d+\z}, pushes.first[:message][:url]
  end

  test "only devices with reminders on, and never at night" do
    assert_empty travel_to(london(2)) { sent { @group.challenges.create!(topic: "times_tables", level: 2) } }, "Bob has no device for them"

    subscribe(@bob)
    assert_empty travel_to(london(2, 21)) { sent { @group.challenges.create!(topic: "times_tables", level: 2) } }
    assert_empty travel_to(london(2, 6)) { sent { @group.challenges.create!(topic: "times_tables", level: 2) } }
    assert_equal 1, travel_to(london(2, 7)) { sent { @group.challenges.create!(topic: "times_tables", level: 2) } }.size
  end

  test "taking 1st place from someone tells them, once a day for each group; a tie or a practice go doesn't" do
    challenge = travel_to(london(2)) { @group.challenges.create!(topic: "times_tables", level: 2, daily: true) }
    subscribe(@owner)
    travel_to(london(2)) do
      assert_empty sent { play(@owner, challenge, right: 10) }, "no one to beat"
      assert_empty sent { play(@bob, challenge, right: 10) }, "a tie"

      pushes = sent { play(@bob, challenge, right: 20) }
      assert_empty pushes, "a practice go: Bob's first was the one that counts"
    end

    travel_to(london(3)) do
      play(@owner, challenge, right: 10)
      pushes = sent { play(@bob, challenge, right: 12) }
      assert_equal [ "😮 Bob just took 1st place from you" ], pushes.map { _1[:message][:title] }
      assert_match "Times tables · Level 2 in Class 4B today. Your first score still counts. See the leaderboard!", pushes.first[:message][:body]

      cat = User.create!(username: "cat", name: "Cat", password: "a long secret phrase")
      @group.join(cat)
      subscribe(@bob)
      assert_equal 1, sent { play(cat, challenge, right: 15) }.size, "Bob, once today"
    end
  end

  test "a one-off nudge explains the first score rule instead of encouraging a ranked replay" do
    subscribe(@owner)
    travel_to(london(2)) do
      challenge = @group.challenges.create!(topic: "times_tables", level: 2)
      play(@owner, challenge, right: 10)
      pushes = sent { play(@bob, challenge, right: 12) }
      assert_match "Your first score still counts. See the leaderboard!", pushes.first[:message][:body]
      assert_empty sent { play(@owner, challenge, right: 15) }, "the replay can't take first place back"
    end
  end
end
