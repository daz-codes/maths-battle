require "test_helper"

class LiveGameTest < ActiveSupport::TestCase
  setup do
    @game = LiveGame.host!(users(:ada))
    @game.join(users(:bob))
    @game.start!
    travel LiveGame::START_LEAD + 1.second
    @ada, @bob = @game.player_for(users(:ada)), @game.player_for(users(:bob))
  end

  test "each player gets their own power-ups, at 3 answers, then 8, 16 and on" do
    assert_empty @game.answered(@ada, 2)
    drops = @game.answered(@ada, 3)
    assert_equal [ users(:ada) ], drops.map(&:owner)
    assert_includes PowerUp::BATTLE.keys, drops.first.power_up
    assert_empty @game.answered(@ada, 7)
    assert_empty @game.answered(@ada, 5), "answers never go back"
    assert_equal 2, @game.answered(@ada, 16).size, "passing 8 and 16 at once"
    assert_empty @game.answered(@bob, 2)
    assert_equal 3, @game.drops.count
  end

  test "only a power-up's owner can claim it, once" do
    drop = @game.answered(@ada, 3).first
    assert_nil @game.claim(drop.id, @bob)
    assert_equal users(:ada), @game.claim(drop.id, @ada).claimed_by
    assert_nil @game.claim(drop.id, @ada)
  end

  test "a player far behind gets an extra power-up, a strong one, but not too often" do
    @ada.update_columns(live_score: 1_000)
    @bob.update_columns(live_score: 200)
    drops = @game.catch_up
    assert_equal [ users(:bob) ], drops.map(&:owner)
    assert_includes LiveGame::Droppable::CATCH_UP, drops.first.power_up
    assert_empty @game.catch_up
    travel LiveGame::Droppable::CATCH_UP_EVERY + 1.second
    assert_equal 1, @game.catch_up.size
    @bob.update_columns(live_score: 800)
    travel LiveGame::Droppable::CATCH_UP_EVERY + 1.second
    assert_empty @game.catch_up, "not when they're close behind"
  end

  test "a streak breaker hits the others at the answer they'd reached" do
    drop = @game.drops.create!(power_up: "reset", owner: users(:bob))
    travel_to(@game.starts_at + 3.5.seconds, with_usec: true) { @game.claim(drop.id, @bob) }
    results = Array.new(6) { { "correct" => true, "ms" => 1000 } }
    assert_equal [ { "kind" => "reset", "at" => 3, "from" => users(:bob).id } ], @game.powers_in(users(:ada), results)
    assert_empty @game.powers_in(users(:bob), results)
  end

  test "a battle's game takes the streak breakers that hit it" do
    drop = @game.drops.create!(power_up: "reset", owner: users(:bob))
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
    drop = @game.drops.create!(power_up: "freeze", owner: users(:bob))
    assert_equal "bomb", @game.claim(drop.id, @bob, random: always).power_up

    again = @game.drops.create!(power_up: "freeze", owner: users(:bob))
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
    drop = @game.drops.create!(power_up: "bomb", owner: users(:bob))
    travel_to(@game.starts_at + 2.5.seconds, with_usec: true) { @game.claim(drop.id, @bob) }
    attempt = play(users(:ada), rights: [ true ] * 4, live_game: @game)
    assert_equal 10 + 20, attempt.score
  end

  test "a Homing shot goes for the leader, and only hits them" do
    game = LiveGame.match!([ users(:bob), users(:ada), users(:cy) ])
    travel LiveGame::START_LEAD + 1.second
    game.player_for(users(:ada)).update_columns(live_score: 500)
    game.player_for(users(:bob)).update_columns(live_score: 200)
    drop = game.drops.create!(power_up: "homing", owner: users(:cy))
    never = Struct.new(:value) { def rand(*) = 1.0 }.new # so it doesn't turn into the Bomb
    claimed = game.claim(drop.id, game.player_for(users(:cy)), random: never)
    assert_equal users(:ada), claimed.target
    assert claimed.hits?(users(:ada))
    assert_not claimed.hits?(users(:bob))
  end

  test "a Shield blocks the next attack, once" do
    horn = @game.drops.create!(power_up: "horn", owner: users(:ada))
    @game.claim(horn.id, @ada)
    assert_equal 1, @ada.reload.horns

    first = @game.claim(@game.drops.create!(power_up: "reset", owner: users(:bob)).id, @bob)
    assert_equal [ users(:ada).id ], first.blocked_ids
    second = @game.claim(@game.drops.create!(power_up: "reset", owner: users(:bob)).id, @bob)
    assert_empty second.blocked_ids
    assert_equal 0, @ada.reload.horns
  end

  test "nothing hits someone with a Superstar running" do
    @game.claim(@game.drops.create!(power_up: "star", owner: users(:ada)).id, @ada)
    bomb = @game.drops.create!(power_up: "bomb", owner: users(:bob))
    assert_equal [ users(:ada).id ], @game.claim(bomb.id, @bob).blocked_ids
    travel LiveGame::STAR_SECONDS + 1
    assert_empty @game.claim(@game.drops.create!(power_up: "reset", owner: users(:bob)).id, @bob).blocked_ids
  end

  test "the Coins and Superstars a player claims count in their own game" do
    travel_to(@game.starts_at + 1.5.seconds, with_usec: true) { @game.claim(@game.drops.create!(power_up: "coins", owner: users(:ada)).id, @ada) }
    attempt = play(users(:ada), rights: [ true ] * 3, live_game: @game)
    assert_equal 10 + 100 + 20 + 30, attempt.score
  end

  test "a Shot goes for the player just ahead, or for the leader the one just behind" do
    game = LiveGame.match!([ users(:ada), users(:bob), users(:cy) ])
    travel LiveGame::START_LEAD + 1.second
    game.player_for(users(:ada)).update_columns(live_score: 500)
    game.player_for(users(:bob)).update_columns(live_score: 200)
    never = Struct.new(:value) { def rand(*) = 1.0 }.new # so Cy's doesn't turn into the Bomb
    shot = game.claim(game.drops.create!(power_up: "shot", owner: users(:cy)).id, game.player_for(users(:cy)), random: never)
    assert_equal users(:bob), shot.target
    shot = game.claim(game.drops.create!(power_up: "shot", owner: users(:ada)).id, game.player_for(users(:ada)))
    assert_equal users(:bob), shot.target
  end

  test "the leader's Rocket is Coins instead" do
    never = Struct.new(:value) { def rand(*) = 1.0 }.new # so Bob's doesn't turn into the Bomb
    @ada.update_columns(live_score: 500)
    assert_equal "coins", @game.claim(@game.drops.create!(power_up: "rocket", owner: users(:ada)).id, @ada).power_up
    assert_equal "rocket", @game.claim(@game.drops.create!(power_up: "rocket", owner: users(:bob)).id, @bob, random: never).power_up
  end

  test "a Curveball someone else threw moves a game's questions where it says, if that's about when it was claimed" do
    curveball = @game.drops.create!(power_up: "curveball", owner: users(:bob))
    travel_to(@game.starts_at + 2.5.seconds, with_usec: true) { @game.claim(curveball.id, @bob) }
    answers = Array.new(6) { { "ms" => 1000 } }
    assert_equal({ 3 => [ 9, 3 ] }, @game.shifts_for(users(:ada), [ { "drop" => curveball.id, "at" => 3 } ], answers, 10))
    assert_raises(Attempt::Invalid) { @game.shifts_for(users(:ada), [ { "drop" => curveball.id, "at" => 6 + 3 } ], answers, 10) }
    assert_raises(Attempt::Invalid) { @game.shifts_for(users(:bob), [ { "drop" => curveball.id, "at" => 3 } ], answers, 10) }
  end

  test "a battle's game follows its Curveball's questions when it's saved" do
    curveball = @game.drops.create!(power_up: "curveball", owner: users(:bob))
    travel_to(@game.starts_at + 1.5.seconds, with_usec: true) { @game.claim(curveball.id, @bob) }
    dealt = pools
    ticket = Attempt::GameTicket.issue(owner: "ada", id: "g", pools: dealt, live_game: @game)
    answers = []
    Ladder.walk(dealt, [ true ] * 5, shifts: { 2 => [ 9, 3 ] }) do |_, (op, a, b), _|
      answers << { "op" => op, "a" => a, "b" => b, "given" => Ladder.answer(op, a, b), "ms" => 1000 }
      [ true, 1000 ]
    end
    game = Attempt::GameTicket.verify!(ticket, owner: "ada", client_id: "g", answers: answers, claims: [], shifts: [ { "drop" => curveball.id, "at" => 2 } ], user: users(:ada))
    assert_equal [ 0, 0, 9, 9, 9 ], game.results.map { |result| result["tier"] }
  end
end
