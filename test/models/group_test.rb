require "test_helper"

class GroupTest < ActiveSupport::TestCase
  setup do
    @owner = users(:ada)
    @group = @owner.owned_groups.create!(name: "Class 4B")
  end

  def challenge(**options)
    @group.challenges.create!(topic: "times_tables", level: 2, **options)
  end

  def play(user, challenge, right:, wrong: 0, played_at: Time.current)
    results = Array.new(right) { { a: 2, b: 3, given: 6, ms: 1000 } } + Array.new(wrong) { { a: 2, b: 3, given: 7, ms: 1000 } }
    Attempt.record!(user: user, topic: "times_tables", level: 2, mode: "group", round: challenge.round, results: results, played_at: played_at.iso8601)
  end

  test "a six character code that can't be misread, found however it's typed; the owner is a member" do
    assert_match(/\A[A-HJ-NP-Z2-9]{6}\z/, @group.join_code)
    assert_equal @group, Group.find_by_code(" #{@group.join_code.downcase} ")
    assert @group.member?(@owner)
    assert @group.owned_by?(@owner)
    assert_not @group.owned_by?(users(:bob))
  end

  test "joining once, and a group has a limit" do
    2.times { @group.join(users(:bob)) }
    assert_equal 2, @group.memberships.count

    (Group::MAX_MEMBERS - 2).times { |i| @group.join(User.create!(username: "player_#{i}", password: "a long secret phrase")) }
    assert_raises(Group::Full) { @group.join(User.create!(username: "one_more", password: "a long secret phrase")) }
  end

  test "a challenge's questions are made once, so everyone plays the same ones" do
    set = challenge
    @group.join(users(:bob))

    assert_equal User::Practisable::QUESTION_COUNT, set.round.questions.size
    assert_equal set.round.questions, Group::Challenge.find(set.id).round.questions
    assert set.round.questions.all? { TimesTables.clean_result(_1.slice("a", "b").merge("given" => _1["answer"]), level: 2)["correct"] }
  end

  test "open until it ends or the owner closes it; the owner plays only if they chose to" do
    week = challenge(ends_at: 1.week.from_now)
    assert week.open?
    travel(8.days) { assert_not week.reload.open? }
    assert_includes Group::Challenge.running, week

    week.close!
    assert_not week.open?
    assert_not_includes Group::Challenge.running, week

    @group.join(users(:bob))
    assert_equal [ users(:bob) ], challenge(owner_plays: false).players.to_a
    assert_equal 2, challenge.players.count
  end

  test "the leaderboard: first goes only, by score then fewer wrong, ties sharing a place" do
    set = challenge
    bob, cat, dan = users(:bob), *%w[ cat dan ].map { User.create!(username: _1, password: "a long secret phrase") }
    [ bob, cat, dan ].each { @group.join(_1) }

    play(@owner, set, right: 10, wrong: 2, played_at: 3.minutes.ago)
    play(bob, set, right: 12, played_at: 2.minutes.ago)
    play(cat, set, right: 10, wrong: 2, played_at: 1.minute.ago)
    play(dan, set, right: 10)
    play(bob, set, right: 30) # practice: the questions are known by then

    board = set.leaderboard
    assert_equal [ bob, dan, @owner, cat ], board.map(&:user)
    assert_equal [ 1, 2, 3, 3 ], board.map(&:rank)
    assert_equal 12, set.entry_for(bob).score
  end

  test "players who leave drop off, and games after it ended don't count" do
    set = challenge(ends_at: 1.day.from_now)
    @group.join(users(:bob))
    play(users(:bob), set, right: 10)
    @group.memberships.find_by(user: users(:bob)).destroy
    assert_empty set.leaderboard

    travel(2.days) { play(@owner, set, right: 10) }
    assert_empty set.reload.leaderboard
  end

  test "a group game is at the challenge's level even if it's locked, and earns no stars or level badge" do
    @group.join(users(:bob))
    game = play(users(:bob), challenge, right: 12)

    assert game.group?
    assert_equal 0, game.stars
    assert_not game.levelled_up
    assert_not game.new_high_score
    assert_equal 1, users(:bob).unlocked_level(TimesTables)
    assert_not_includes users(:bob).badges.pluck(:kind), "level_2_times_tables"
  end

  test "only the challenge's players, for its topic and level, and only group games have a round" do
    set = challenge
    assert_raises(Attempt::Invalid) { play(users(:bob), set, right: 5) }
    @group.join(users(:bob))
    assert_raises(Attempt::Invalid) { Attempt.record!(user: users(:bob), topic: "times_tables", level: 3, mode: "group", round: set.round, results: []) }
    assert_raises(Attempt::Invalid) { Attempt.record!(user: users(:bob), topic: "times_tables", level: 1, results: [], round: set.round) }
    assert_raises(Attempt::Invalid) { Attempt.record!(user: users(:bob), topic: "times_tables", level: 2, mode: "group", results: []) }
  end

  test "the challenges waiting for a player: open ones they play and haven't yet" do
    @group.join(users(:bob))
    waiting = challenge
    challenge.close!
    watched = challenge(owner_plays: false)

    assert_equal [ watched, waiting ].sort_by(&:id), users(:bob).group_challenges_to_play.sort_by(&:id)
    assert_equal [ waiting ], @owner.group_challenges_to_play

    play(users(:bob), waiting, right: 5)
    assert_equal [ watched ], User.find(users(:bob).id).group_challenges_to_play
  end

  test "only an account can make a group" do
    assert @owner.can_make_groups?
    assert_not User.create_guest!.can_make_groups?
  end

  def london(day, hour = 12) = ActiveSupport::TimeZone["London"].local(2026, 11, day, hour)

  def daily(**options)
    @group.challenges.create!(topic: "times_tables", level: 2, daily: true, **options)
  end

  test "an every day challenge has a fresh round each day, the same for everyone, by the group's time zone" do
    set = travel_to(london(2)) { daily }
    monday = travel_to(london(2, 9)) { set.round }
    assert_equal monday, travel_to(london(2, 23)) { set.round }, "the same all day"

    tuesday = travel_to(london(3, 1)) { set.round }
    assert_not_equal monday, tuesday
    assert_equal Date.new(2026, 11, 3), tuesday.day
    assert_not_equal monday.questions.map { _1["text"] }, tuesday.questions.map { _1["text"] }

    @owner.update!(time_zone: "America/New_York")
    assert_equal monday, travel_to(london(3, 1)) { set.round }, "still Monday evening in New York"
  end

  test "only today's round can be played; a one-off's only round is always current" do
    set = travel_to(london(2)) { daily }
    monday = travel_to(london(2)) { set.round }
    travel_to(london(3)) do
      assert_not monday.current?
      assert set.round.current?
    end
    once = challenge
    assert once.round.current?
    assert_equal 1, once.rounds.count
  end

  test "the week's leaderboards: each player's first go each day, by total or by best day" do
    set = travel_to(london(2)) { daily }
    @group.join(users(:bob))
    bob = users(:bob)
    travel_to(london(2)) { play(bob, set, right: 15); play(@owner, set, right: 9) }
    travel_to(london(3)) { play(bob, set, right: 5); play(@owner, set, right: 10); play(@owner, set, right: 30) }
    travel_to(london(4)) { play(@owner, set, right: 10) }

    travel_to(london(4)) do
      total = set.week_leaderboard(by: :total)
      assert_equal [ @owner, bob ], total.map(&:user)
      assert_equal [ [ 29, 10, 3 ], [ 20, 15, 2 ] ], total.map { [ _1.total, _1.best, _1.days ] }, "Tuesday's second go was just practice"

      assert_equal [ bob, @owner ], set.week_leaderboard(by: :best).map(&:user)
      assert_equal [ @owner ], set.leaderboard.map(&:user), "today's"
    end

    travel_to(london(9)) { assert_empty set.week_leaderboard, "a new week starts on Monday" }
  end

  test "an every day challenge waits for the player again each day" do
    set = travel_to(london(2)) { daily }
    @group.join(users(:bob))
    travel_to(london(2)) do
      play(users(:bob), set, right: 5)
      assert_empty User.find(users(:bob).id).group_challenges_to_play
    end
    travel_to(london(3)) { assert_equal [ set ], User.find(users(:bob).id).group_challenges_to_play }
  end

  test "a replay cannot replace the first saved score by backdating its clock" do
    set = challenge
    first = play(@owner, set, right: 3, played_at: 4.minutes.from_now)
    play(@owner, set, right: 30, played_at: 2.minutes.ago)

    assert_equal first, set.entry_for(@owner).attempt
    assert_equal 3, set.entry_for(@owner).score
  end

  test "late scores are kept in history but cannot change a closed leaderboard, even when backdated" do
    set = challenge
    @group.join(users(:bob))
    first = play(@owner, set, right: 3)
    set.close!
    travel 1.minute do
      late = play(users(:bob), set, right: 30, played_at: 2.minutes.ago)
      assert late.persisted?
      assert_equal [ first ], set.leaderboard.map(&:attempt)
    end
  end

  test "yesterday's ticket can save history but cannot fill yesterday's leaderboard" do
    set = travel_to(london(2)) { daily }
    monday = set.rounds.first
    travel_to(london(3)) do
      results = [ { a: 2, b: 3, given: 6, ms: 1000 } ]
      late = Attempt.record!(user: @owner, topic: "times_tables", level: 2, mode: "group", round: monday,
        results: results, played_at: london(2).iso8601)
      assert late.persisted?
      assert_empty set.leaderboard(monday)
      assert_empty set.week_leaderboard
    end
  end

  test "closed daily challenges keep their final round and week without making more rounds" do
    set = travel_to(london(2)) { daily }
    travel_to(london(2)) { play(@owner, set, right: 3) }
    travel_to(london(3)) do
      play(@owner, set, right: 5)
      set.close!
    end
    final_round = set.round

    travel_to(london(16)) do
      assert_no_difference "set.rounds.count" do
        assert_equal final_round, set.round
        assert_equal [ 5 ], set.leaderboard.map(&:score)
        assert_equal [ [ 8, 5, 2 ] ], set.week_leaderboard.map { |entry| [ entry.total, entry.best, entry.days ] }
      end
    end
  end

  test "an expired challenge keeps its last round even if it ended at midnight" do
    set = travel_to(london(2)) { daily(ends_at: london(3, 0)) }
    travel_to(london(2)) { play(@owner, set, right: 3) }
    travel_to(london(16)) do
      assert_no_difference "set.rounds.count" do
        assert_equal Date.new(2026, 11, 2), set.round.day
        assert_equal [ 3 ], set.leaderboard.map(&:score)
        assert_equal [ 3 ], set.week_leaderboard.map(&:total)
      end
    end
  end

  test "a competing round insert returns the existing daily or one-off round" do
    [ challenge, daily ].each do |set|
      existing = set.round
      # Simulate another request inserting after the first SELECT missed, before this request's INSERT.
      set.rounds.define_singleton_method(:find_by) { |*| nil }

      assert_equal existing, set.round
      assert_equal 1, set.rounds.count
    end
  end

  test "an old code cannot join after rotation even when the group was loaded before the change" do
    stale = Group.find(@group.id)
    old_code = @group.join_code
    @group.renew_join_code!

    assert_raises(Group::InvalidCode) { stale.join(users(:bob), code: old_code) }
    assert_not @group.member?(users(:bob))
    @group.join(users(:bob), code: @group.join_code.downcase)
    assert @group.member?(users(:bob))
  end

  test "checking waiting challenges does not make a daily round or read historical question sets" do
    set = travel_to(london(2)) { daily }
    travel_to(london(3)) do
      assert_no_difference "set.rounds.count" do
        assert_equal [ set ], @owner.group_challenges_to_play
      end
    end
  end
end
