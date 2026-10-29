require "test_helper"
require "turbo/broadcastable/test_helper"

class LiveGameTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  setup do
    @ada, @bob = users(:ada), users(:bob)
    @game = LiveGame.make(host: @ada, topic: TimesTables, level: 1)
  end

  def player(name)
    User.create!(username: name, name: name.capitalize, password: "a long password 123")
  end

  def play(user, right:, wrong: 0, game: @game)
    results = Array.new(right) { { a: 2, b: 3, given: 6, ms: 1000 } } + Array.new(wrong) { { a: 2, b: 3, given: 7, ms: 1000 } }
    Attempt.record!(user: user, topic: "times_tables", level: 1, mode: "live", live_game: game, results: results)
  end

  test "the host makes a lobby with a code, at their topic and level, and is its first player" do
    assert_match(/\A[A-HJ-NP-Z2-9]{5}\z/, @game.code)
    assert_equal [ @ada ], @game.users.to_a
    assert_equal User::QUESTION_COUNT, @game.questions.size
    assert_equal @game, LiveGame.find_by_code(@game.code.downcase)
  end

  test "joining until it's full or started, and the lobby hears who's joined" do
    assert_turbo_stream_broadcasts(@game) { assert @game.join(@bob) }
    assert @game.join(@bob), "already in"
    assert_equal 2, @game.players.count

    6.times { |i| @game.join(player("player#{i}")) }
    assert_not @game.join(player("late")), "8 is the most"

    other = LiveGame.make(host: @ada, topic: TimesTables, level: 1)
    other.join(@bob)
    other.start!
    assert_not other.join(player("after"))

    stale = LiveGame.make(host: @ada, topic: TimesTables, level: 1)
    travel(31.minutes) { assert_not stale.join(@bob) }
  end

  test "the host starts it once someone else has joined, a few seconds ahead, for a minute" do
    assert_not @game.start!, "no one to play"
    @game.join(@bob)
    freeze_time do
      assert_turbo_stream_broadcasts(@game) { assert @game.start! }
      assert_equal 6.seconds.from_now, @game.starts_at
      assert_equal 66.seconds.from_now, @game.ends_at
      assert_not @game.start!, "only once"
    end
    travel(10.seconds) { assert @game.running? }
    travel(70.seconds) { assert @game.over? }
  end

  test "only its players, once it's started, at its level" do
    @game.join(@bob)
    assert_raises(Attempt::Invalid) { play(@bob, right: 3) }
    @game.start!
    assert_raises(Attempt::Invalid) { play(player("carol"), right: 3) }
    assert_raises(Attempt::Invalid) do
      Attempt.record!(user: @bob, topic: "times_tables", level: 2, mode: "live", live_game: @game, results: [ { a: 2, b: 3, given: 6, ms: 1000 } ])
    end
  end

  test "the podium: by score then fewer wrong, ties sharing a place, first games only, those still playing last" do
    carol, dan = player("carol"), player("dan")
    [ @bob, carol, dan ].each { @game.join(_1) }
    @game.start!

    travel 30.seconds do
      play(@ada, right: 10, wrong: 1)
      assert_turbo_stream_broadcasts(@game) { play(@bob, right: 12) }
      play(carol, right: 10, wrong: 1)
      play(@bob, right: 30)
    end

    podium = @game.podium
    assert_equal [ [ 1, @bob, 12 ], [ 2, @ada, 10 ], [ 2, carol, 10 ], [ nil, dan, nil ] ], podium.map { [ _1.rank, _1.user, _1.correct ] }
    assert_equal 2, @game.place_of(carol).rank

    travel(5.minutes) { play(dan, right: 40) }
    assert_nil @game.place_of(dan).rank, "saved too late to count"
  end

  test "Classic or Power, the podium goes by score, so speed and runs of right answers count, not just how many" do
    @game.join(@bob)
    assert_turbo_stream_broadcasts(@game) { assert @game.choose_mode("power") }
    assert_not @game.choose_mode("chaos")
    @game.start!
    assert_not @game.choose_mode("classic"), "not once it's started"

    travel 30.seconds do
      Attempt.record!(user: @ada, topic: "times_tables", level: 1, mode: "live", live_game: @game, results: Array.new(6) { { a: 2, b: 3, given: 6, ms: 500 } })
      Attempt.record!(user: @bob, topic: "times_tables", level: 1, mode: "live", live_game: @game, results: Array.new(8) { { a: 2, b: 3, given: 6, ms: 3000 } })
    end

    assert_equal [ [ 1, @ada, 240, 6 ], [ 2, @bob, 120, 8 ] ], @game.podium.map { [ _1.rank, _1.user, _1.score, _1.correct ] },
      "6 lightning answers, the 5th and 6th doubled, beat 8 slow ones"
    @game.update!(mode: "classic")
    assert_equal [ @ada, @bob ], @game.podium.map(&:user)
  end

  test "playing again: once it's started, the host makes the next game once, at the same topic, level and mode, and everyone looking hears" do
    @game.join(@bob)
    @game.update!(mode: "power")
    assert_nil @game.play_again!, "not before it's started"

    @game.start!
    rematch = nil
    assert_turbo_stream_broadcasts(@game) { rematch = @game.play_again! }
    assert_equal [ "times_tables", 1, "power", @ada ], [ rematch.topic, rematch.level, rematch.mode, rematch.host ]
    assert_equal [ @ada ], rematch.users.to_a, "the others join from the podium"
    assert rematch.joinable?
    assert_not_equal @game.code, rematch.code
    assert_equal rematch, @game.reload.rematch
    assert_equal rematch, @game.play_again!, "only once"
    assert_equal 2, LiveGame.count
  end

  test "a live game doesn't change a level's best" do
    @game.join(@bob)
    @game.start!
    game = play(@bob, right: 20)
    assert_not game.new_high_score
    assert_equal 0, @bob.best_score(TimesTables, 1)
  end
end
