require "test_helper"

class Attempt::GameTicketTest < ActiveSupport::TestCase
  setup do
    @pools = pools
    @powers = PowerUp.deal_solo(random: Random.new(2))
    @ticket = Attempt::GameTicket.issue(owner: "me", id: "game-1", pools: @pools, powers: @powers)
  end

  def verify(answers, claims: [], owner: "me", id: "game-1")
    Attempt::GameTicket.verify!(@ticket, owner: owner, client_id: id, answers: answers, claims: claims)
  end

  test "answers walking the ladder are marked right or wrong with their tier" do
    game = verify(walk_answers(@pools, [ true, true, true, false ]))
    assert_equal "solo", game.mode
    assert_equal [ true, true, true, false ], game.results.map { |result| result["correct"] }
    assert_equal [ 0, 0, 0, 1 ], game.results.map { |result| result["tier"] }
  end

  test "an answer to a question the ladder wouldn't have asked is refused" do
    answers = walk_answers(@pools, [ true, true, true, true ])
    answers[3] = answers[3].merge("a" => "99", "b" => "99")
    assert_raises(Attempt::Invalid) { verify(answers) }
  end

  test "wrong answers can't be followed by the questions of a higher tier" do
    climbed = walk_answers(@pools, [ true ] * 4)
    wrong = walk_answers(@pools, [ false ] * 3) + [ climbed[3] ]
    assert_raises(Attempt::Invalid) { verify(wrong) }
  end

  test "another player's or another game's ticket is refused" do
    answers = walk_answers(@pools, [ true ])
    assert_raises(Attempt::Invalid) { verify(answers, owner: "someone else") }
    assert_raises(Attempt::Invalid) { verify(answers, id: "game-2") }
  end

  test "a claimed power-up is the one dealt for its spinner" do
    game = verify(walk_answers(@pools, [ true ] * 12), claims: [ { "drop" => 1, "at" => 11 } ])
    assert_equal [ { "kind" => @powers.first, "drop" => 1, "at" => 11 } ], game.powers
  end

  test "a spinner can't be claimed before it appears, after the next takes its place, or twice" do
    answers = walk_answers(@pools, [ true ] * 25)
    assert_raises(Attempt::Invalid) { verify(answers, claims: [ { "drop" => 1, "at" => 9 } ]) }
    assert_raises(Attempt::Invalid) { verify(answers, claims: [ { "drop" => 1, "at" => 20 } ]) }
    assert_raises(Attempt::Invalid) { verify(answers, claims: [ { "drop" => 1, "at" => 10 }, { "drop" => 1, "at" => 12 } ]) }
    assert_raises(Attempt::Invalid) { verify(answers, claims: [ { "drop" => 3, "at" => 30 } ]) }
  end
end
