require "test_helper"

class HeadToHeadTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @ada, @bob = users(:ada), users(:bob)
    @ada.update!(name: "Ada")
    @bob.update!(name: "Bob")
    @group = @ada.owned_groups.create!(name: "Class 4B")
    @group.join(@bob)
  end

  def tables_results(right:, wrong: 0)
    Array.new(right) { { a: 2, b: 3, given: 6, ms: 1000 } } + Array.new(wrong) { { a: 2, b: 3, given: 7, ms: 1000 } }
  end

  def play(user, head_to_head, right:, wrong: 0)
    Attempt.record!(user: user, topic: "times_tables", level: head_to_head.level, mode: "head_to_head", head_to_head: head_to_head,
      results: tables_results(right: right, wrong: wrong))
  end

  def sent_game(right: 10, wrong: 0)
    game = record_tables_game(@ada, tables_results(right: right, wrong: wrong))
    HeadToHead.from_game(game, opponent: @bob)
  end

  test "rivals are people in a group together, or played before; no one else, and not themselves" do
    carol = User.create!(username: "carol", password: "a long password 123")
    assert_equal [ @bob ], @ada.rivals.to_a
    assert_empty carol.rivals
    assert_not @ada.rival?(carol)
    assert_raises(ActiveRecord::RecordInvalid) { HeadToHead.fresh(challenger: @ada, opponent: carol, topic: TimesTables, level: 1) }

    head_to_head = HeadToHead.fresh(challenger: @ada, opponent: @bob, topic: TimesTables, level: 1)
    @group.remove(@group.memberships.find_by(user: @bob))
    assert_equal [ @bob ], @ada.rivals.to_a, "they've played, so they stay rivals"
    assert_equal [ @ada ], @bob.rivals.to_a
    assert head_to_head.persisted?
  end

  test "a game sent as it is: the questions the challenger answered, then more of the same level, and 3 days to play" do
    head_to_head = sent_game(right: 8, wrong: 2)

    assert head_to_head.sent?
    assert_equal [ "times_tables", 2, false ], [ head_to_head.topic, head_to_head.level, head_to_head.mixed ]
    assert_equal User::QUESTION_COUNT, head_to_head.questions.size
    assert_equal [ { "a" => "2", "b" => "3", "text" => "2 × 3", "answer" => "6" } ] * 10, head_to_head.questions.first(10).map { _1.slice("a", "b", "text", "answer") }
    assert_in_delta 3.days.from_now, head_to_head.expires_at, 5
    assert head_to_head.turn?(@bob)
    assert_not head_to_head.turn?(@ada)
    assert_equal [ head_to_head ], @bob.head_to_heads_to_play.to_a
  end

  test "the higher score wins, then fewer wrong; the same is a draw. Records add up for both" do
    play(@bob, sent_game(right: 10), right: 12)
    play(@bob, sent_game(right: 10, wrong: 1), right: 10)
    play(@bob, sent_game(right: 10), right: 10)
    play(@bob, sent_game(right: 15), right: 3)

    assert_equal User::HeadToHeadable::Record.new(won: 1, lost: 2, drew: 1), @ada.head_to_head_record(@bob)
    assert_equal User::HeadToHeadable::Record.new(won: 2, lost: 1, drew: 1), @bob.head_to_head_record(@ada)
    assert_equal :lost, @ada.head_to_heads.order(:id).first.result_for(@ada)
    assert_empty @bob.head_to_heads_to_play
  end

  test "only each player's first go counts, and a late one changes nothing" do
    head_to_head = sent_game(right: 10)
    first = play(@bob, head_to_head, right: 5)
    play(@bob, head_to_head, right: 20)
    assert_equal [ first, @ada ], [ head_to_head.reload.opponent_attempt, head_to_head.winner ]

    late = sent_game(right: 10)
    travel 4.days do
      assert late.ran_out?
      game = play(@bob, late, right: 20)
      assert_equal "head_to_head", game.mode
      assert_nil late.reload.opponent_attempt
      assert_not late.decided?
      assert_empty @bob.head_to_heads_to_play
    end
  end

  test "a fresh one is the challenger's to play first, and is only sent when they have" do
    head_to_head = HeadToHead.fresh(challenger: @ada, opponent: @bob, topic: TimesTables, level: 1)
    assert head_to_head.turn?(@ada)
    assert_not head_to_head.turn?(@bob)
    assert_empty @bob.head_to_heads_to_play

    play(@ada, head_to_head, right: 9)
    assert head_to_head.reload.sent?
    assert head_to_head.turn?(@bob)
  end

  test "only its two players can play it, at its level" do
    carol = User.create!(username: "carol", password: "a long password 123")
    head_to_head = sent_game
    assert_raises(Attempt::Invalid) { play(carol, head_to_head, right: 5) }
    assert_raises(Attempt::Invalid) { Attempt.record!(user: @bob, topic: "times_tables", level: 1, mode: "head_to_head", head_to_head: head_to_head, results: tables_results(right: 1)) }
    assert_raises(Attempt::Invalid) { Attempt.record!(user: @bob, topic: "times_tables", level: 1, mode: "practice", head_to_head: head_to_head, results: tables_results(right: 1)) }
  end

  test "the opponent hears when it's sent, and the challenger how it went" do
    @ada.turn_on_reminders!(17 * 60, **push_keys(endpoint: "https://fcm.googleapis.com/fcm/send/ada"))
    @bob.turn_on_reminders!(17 * 60, **push_keys(endpoint: "https://fcm.googleapis.com/fcm/send/bob"))

    travel_to ActiveSupport::TimeZone["London"].local(2026, 11, 2, 12) do
      head_to_head = nil
      pushes = pushes_sent { perform_enqueued_jobs { head_to_head = sent_game(right: 10) } }
      assert_equal [ "https://fcm.googleapis.com/fcm/send/bob" ], pushes.map { _1[:endpoint] }
      assert_equal "⚔️ Ada has challenged you!", pushes.first[:message][:title]
      assert_equal "Beat 10 at Times tables · Level 2. Same questions, one go each.", pushes.first[:message][:body]
      assert_equal "/head_to_heads/#{head_to_head.id}", pushes.first[:message][:url]

      pushes = pushes_sent { perform_enqueued_jobs { play(@bob, head_to_head, right: 12) } }
      assert_equal [ "https://fcm.googleapis.com/fcm/send/ada" ], pushes.map { _1[:endpoint] }
      assert_equal "😮 Bob beat you!", pushes.first[:message][:title]
      assert_equal "10–12 at Times tables · Level 2. Fancy a rematch?", pushes.first[:message][:body]
    end
  end

  test "a link is taken up once, not by the challenger, and not after it's run out" do
    carol = User.create!(username: "carol", password: "a long password 123")
    link = HeadToHead.from_game(record_tables_game(@ada, tables_results(right: 5)))
    assert link.link?
    assert_not link.claim(@ada)
    assert link.claim(carol)
    assert_not link.claim(@bob)
    assert_equal carol, link.reload.opponent

    late = HeadToHead.from_game(record_tables_game(@ada, tables_results(right: 5)))
    travel(4.days) { assert_not late.claim(carol) }
  end

  test "a player who's deleted takes their head to heads with them" do
    sent_game
    assert_difference "HeadToHead.count", -1 do
      @bob.destroy!
    end
  end
end
