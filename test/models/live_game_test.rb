require "test_helper"

class LiveGameTest < ActiveSupport::TestCase
  setup do
    @game = LiveGame.host!(users(:ada))
    @game.join(users(:bob))
    @game.start!
    travel LiveGame::START_LEAD + 1.second
    @ada, @bob = @game.player_for(users(:ada)), @game.player_for(users(:bob))
  end

  test "a power-up drops each time a player passes another ten answers" do
    assert_nil @game.answered(@ada, 9)
    drop = @game.answered(@ada, 10)
    assert_includes PowerUp::BATTLE.keys, drop.power_up
    assert_nil @game.answered(@ada, 15)
    assert_nil @game.answered(@ada, 12), "answers never go back"
    assert @game.answered(@bob, 11)
    assert_equal 2, @game.drops.count
  end

  test "the first to claim a power-up gets it" do
    drop = @game.answered(@ada, 10)
    assert_equal users(:bob), @game.claim(drop.id, @bob).claimed_by
    assert_nil @game.claim(drop.id, @ada)
  end

  test "a streak breaker hits the others at the answer they'd reached" do
    drop = @game.drops.create!(power_up: "reset")
    travel_to(@game.starts_at + 3.5.seconds, with_usec: true) { @game.claim(drop.id, @bob) }
    results = Array.new(6) { { "correct" => true, "ms" => 1000 } }
    assert_equal [ { "kind" => "reset", "at" => 3, "from" => users(:bob).id } ], @game.powers_in(users(:ada), results)
    assert_empty @game.powers_in(users(:bob), results)
  end

  test "a battle's game takes the streak breakers that hit it" do
    drop = @game.drops.create!(power_up: "reset")
    travel_to(@game.starts_at + 2.5.seconds, with_usec: true) { @game.claim(drop.id, @bob) }
    attempt = play(users(:ada), rights: [ true ] * 4, live_game: @game)
    assert_equal "battle", attempt.mode
    assert_equal 10 + 20 + 10 + 20, attempt.score
    assert_equal attempt, @ada.reload.attempt
  end

  test "only its players can save a battle's game" do
    assert_raises(Attempt::Invalid) { play(users(:cy), live_game: @game) }
  end

  test "matchmaking's battles start at once, with no host" do
    game = LiveGame.match!([ users(:ada), users(:cy) ])
    assert game.matched?
    assert game.started?
    assert_equal [ users(:ada), users(:cy) ], game.users.to_a
    assert_nil game.play_again!
  end

  test "a drop claimed by someone far behind a leader worth bombing can be the Bomb, once a battle" do
    @ada.update_columns(live_score: 1_000)
    @bob.update_columns(live_score: 100)
    always = Struct.new(:value) { def rand(*) = 0.0 }.new
    drop = @game.drops.create!(power_up: "freeze")
    assert_equal "bomb", @game.claim(drop.id, @bob, random: always).power_up

    again = @game.drops.create!(power_up: "freeze")
    assert_equal "freeze", @game.claim(again.id, @bob, random: always).power_up, "only one a battle"
  end

  test "the leader, or someone close behind, never gets the Bomb" do
    always = Struct.new(:value) { def rand(*) = 0.0 }.new
    @ada.update_columns(live_score: 1_000)
    @bob.update_columns(live_score: 700)
    assert_not @game.bomb_for?(@bob, always)
    assert_not @game.bomb_for?(@ada, always)
  end

  test "a Bomb hits the others' games where it was claimed" do
    drop = @game.drops.create!(power_up: "bomb")
    travel_to(@game.starts_at + 2.5.seconds, with_usec: true) { @game.claim(drop.id, @bob) }
    attempt = play(users(:ada), rights: [ true ] * 4, live_game: @game)
    assert_equal 10 + 20, attempt.score
  end

  test "a Homing shot goes for the leader, and only hits them" do
    game = LiveGame.match!([ users(:ada), users(:bob), users(:cy) ])
    travel LiveGame::START_LEAD + 1.second
    game.player_for(users(:ada)).update_columns(live_score: 500)
    game.player_for(users(:bob)).update_columns(live_score: 200)
    drop = game.drops.create!(power_up: "homing")
    never = Struct.new(:value) { def rand(*) = 1.0 }.new # so it doesn't turn into the Bomb
    claimed = game.claim(drop.id, game.player_for(users(:cy)), random: never)
    assert_equal users(:ada), claimed.target
    assert claimed.hits?(users(:ada))
    assert_not claimed.hits?(users(:bob))
  end

  test "a Horn blocks the next attack, once" do
    horn = @game.drops.create!(power_up: "horn")
    @game.claim(horn.id, @ada)
    assert_equal 1, @ada.reload.horns

    first = @game.claim(@game.drops.create!(power_up: "reset").id, @bob)
    assert_equal [ users(:ada).id ], first.blocked_ids
    second = @game.claim(@game.drops.create!(power_up: "reset").id, @bob)
    assert_empty second.blocked_ids
    assert_equal 0, @ada.reload.horns
  end

  test "nothing hits someone with a Superstar running" do
    @game.claim(@game.drops.create!(power_up: "star").id, @ada)
    bomb = @game.drops.create!(power_up: "bomb")
    assert_equal [ users(:ada).id ], @game.claim(bomb.id, @bob).blocked_ids
    travel LiveGame::STAR_SECONDS + 1
    assert_empty @game.claim(@game.drops.create!(power_up: "reset").id, @bob).blocked_ids
  end

  test "the Coins and Superstars a player claims count in their own game" do
    travel_to(@game.starts_at + 1.5.seconds, with_usec: true) { @game.claim(@game.drops.create!(power_up: "coins").id, @ada) }
    attempt = play(users(:ada), rights: [ true ] * 3, live_game: @game)
    assert_equal 10 + 100 + 20 + 30, attempt.score
  end
end
