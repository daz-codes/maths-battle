require "test_helper"

class LiveGame::PowerableTest < ActiveSupport::TestCase
  setup do
    @ada, @bob = users(:ada), users(:bob)
    @carol = User.create!(username: "carol", password: "a long password 123")
    @game = LiveGame.make(host: @ada, topic: TimesTables, level: 1)
    [ @bob, @carol ].each { @game.join(_1) }
    @game.update!(mode: "power")
  end

  def player(user) = @game.player_for(user)

  def standings(ada:, bob:, carol:)
    { @ada => ada, @bob => bob, @carol => carol }.each { |user, gems| player(user).update!(live_gems: gems) }
  end

  test "three boxes, at 15, 30 and 45 seconds, only in a running Power game" do
    @game.start!
    starts = @game.starts_at
    travel_to(starts + 10.seconds) { assert_nil @game.open_box(player(@ada)), "not yet" }
    travel_to(starts + 15.seconds) { assert @game.open_box(player(@ada)) }
    travel_to(starts + 16.seconds) { assert_nil @game.open_box(player(@ada)), "the next is at 30" }
    travel_to(starts + 29.5.seconds, with_usec: true) { assert @game.open_box(player(@ada)), "a moment early, by a device's clock" }
    travel_to(starts + 59.seconds) do
      assert @game.open_box(player(@ada))
      assert_nil @game.open_box(player(@ada)), "three a game"
      assert_equal 3, player(@ada).boxes_opened
    end
    travel_to(starts + 61.seconds) { assert_nil @game.open_box(player(@bob)), "it's over" }

    classic = LiveGame.make(host: @ada, topic: TimesTables, level: 1)
    classic.join(@bob)
    classic.start!
    travel_to(classic.starts_at + 16.seconds) { assert_nil classic.open_box(classic.player_for(@ada)) }
  end

  test "what's inside depends on place: defence for the leader, the strongest attacks for last place" do
    standings(ada: 300, bob: 200, carol: 100)
    assert_equal [ :leading, :middle, :last ], [ @ada, @bob, @carol ].map { @game.place_of_player(player(_1)) }

    @game.start!
    travel_to(@game.starts_at + 16.seconds) do
      dealt = 200.times.map { |i| @game.send(:draw, :leading, Random.new(i)) }.tally
      assert_equal %w[ flip shield shrink ], dealt.keys.sort
      assert_operator dealt["shield"], :>, dealt["flip"]
      assert_equal %w[ flip freeze ink lightning scramble shrink ], 200.times.map { |i| @game.send(:draw, :last, Random.new(i)) }.uniq.sort
      assert @game.open_box(player(@carol), random: Random.new(1)).in?(LiveGame::ODDS[:last].keys)
    end
  end

  test "an attack hits the player just ahead, or second place for the leader; Lightning everyone ahead; it's used up" do
    standings(ada: 300, bob: 200, carol: 100)
    @game.start!
    travel_to(@game.starts_at + 20.seconds) do
      player(@carol).update!(power_up: "freeze")
      assert_equal({ power_up: "freeze", from: @carol.id, hit: [ @bob.id ], blocked: [] }, @game.use_power_up(player(@carol)))
      assert_nil player(@carol).reload.power_up
      assert_nil @game.use_power_up(player(@carol)), "nothing left to use"

      player(@ada).update!(power_up: "flip")
      assert_equal [ @bob.id ], @game.use_power_up(player(@ada))[:hit], "the leader hits second place"

      player(@carol).update!(power_up: "lightning")
      assert_equal [ @ada.id, @bob.id ].sort, @game.use_power_up(player(@carol))[:hit].sort
    end
  end

  test "a Shield held blocks the next attack, and is used up doing it; it can't be used itself" do
    standings(ada: 300, bob: 200, carol: 100)
    @game.start!
    travel_to(@game.starts_at + 20.seconds) do
      player(@bob).update!(power_up: "shield")
      assert_nil @game.use_power_up(player(@bob))

      player(@carol).update!(power_up: "scramble")
      assert_equal({ power_up: "scramble", from: @carol.id, hit: [], blocked: [ @bob.id ] }, @game.use_power_up(player(@carol)))
      assert_nil player(@bob).reload.power_up
    end
  end
end
