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
    assert_equal [ { "kind" => "reset", "at" => 3, "from" => users(:bob).id } ], @game.hits_on(users(:ada), results)
    assert_empty @game.hits_on(users(:bob), results)
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
end
