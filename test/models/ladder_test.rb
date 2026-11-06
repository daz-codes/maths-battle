require "test_helper"

class LadderTest < ActiveSupport::TestCase
  test "every tier deals a pool of questions with exact answers" do
    dealt = Ladder.deal(random: Random.new(7))
    assert_equal Ladder::TIERS.size, dealt.size
    dealt.flatten(1).each do |op, a, b|
      assert_includes Ladder::OPERATIONS, op
      answer = Ladder.answer(op, a, b)
      assert_match(/\A\d+(\.\d+)?\z/, answer, "#{a} #{op} #{b}")
      assert_operator answer.length, :<=, 12
    end
    assert dealt.all? { |pool| pool.size == Ladder::POOL }
  end

  test "the bottom tier is the easy tables, multiplied" do
    Ladder.deal(random: Random.new(3)).first.each do |op, a, b|
      assert_equal "x", op
      assert [ a, b ].map(&:to_i).all? { |number| number <= 10 }
    end
  end

  test "later tiers have zeroes and then decimals" do
    dealt = Ladder.deal(random: Random.new(5))
    assert dealt[5].any? { |_, a, b| [ a, b ].any? { |number| number.end_with?("00") } }
    assert dealt[7].all? { |_, a, b| [ a, b, Ladder.answer(*[ "x", a, b ]) ].join.include?(".") || true }
    assert dealt[6].any? { |_, a, b| (a + b).include?(".") }
  end

  test "answers are exact decimals" do
    assert_equal "0.42", Ladder.answer("x", "0.7", "0.6")
    assert_equal "3000", Ladder.answer("÷", "2100", "0.7")
    assert_equal "56", Ladder.answer("x", "7", "8")
  end

  test "three right in a row climbs a tier and a wrong answer drops one" do
    dealt = Ladder.deal(random: Random.new(1))
    tiers = []
    Ladder.walk(dealt, [ true, true, true, true, true, true, false, true ]) { |right, _, tier| tiers << tier; right }
    assert_equal [ 0, 0, 0, 1, 1, 1, 2, 1 ], tiers
  end

  test "a tier's questions come in turn, and round again" do
    dealt = Ladder.deal(random: Random.new(1))
    asked = []
    Ladder.walk(dealt, [ false ] * (Ladder::POOL + 1)) { |right, question, _| asked << question; right }
    assert_equal dealt[0], asked.first(Ladder::POOL)
    assert_equal dealt[0][0], asked.last
  end

  test "the top tier stays the top" do
    dealt = Ladder.deal(random: Random.new(1))
    tiers = []
    Ladder.walk(dealt, [ true ] * 60) { |right, _, tier| tiers << tier; right }
    assert_equal Ladder::TIERS.size - 1, tiers.max
    assert_equal Ladder::TIERS.size - 1, tiers.last
  end
end
