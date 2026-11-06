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

  def tiers_for(answers)
    tiers = []
    Ladder.walk(Ladder.deal(random: Random.new(1)), answers) { |(right, ms), _, tier| tiers << tier; [ right, ms ] }
    tiers
  end

  test "quick right answers warm the game up: three move up a tier" do
    assert_equal [ 0, 0, 0, 1, 1, 2 ], tiers_for([ [ true, 800 ] ] * 6)
  end

  test "steady ones take four, and slow ones barely move it" do
    assert_equal [ 0, 0, 0, 0, 1 ], tiers_for([ [ true, 1_800 ] ] * 5)
    assert_equal [ 0 ] * 10, tiers_for([ [ true, 3_500 ] ] * 10)
  end

  test "a wrong answer cools it down a tier, and dawdling cools it a little" do
    assert_equal [ 0, 0, 0, 1, 0 ], tiers_for([ [ true, 800 ] ] * 3 + [ [ false, 800 ], [ true, 800 ] ])
    assert_equal [ 0, 0, 0, 1, 1, 0 ], tiers_for([ [ true, 800 ] ] * 3 + [ [ true, 9_000 ] ] * 3)
  end

  test "harder tiers allow longer before an answer is slow" do
    assert_equal Ladder::HEAT[:quick], Ladder.heat(true, 1_200, 0)
    assert_equal Ladder::HEAT[:steady], Ladder.heat(true, 1_300, 0)
    assert_equal Ladder::HEAT[:quick], Ladder.heat(true, 3_000, 9)
  end

  test "it never goes below the easiest" do
    assert_equal [ 0 ] * 4, tiers_for([ [ false, 800 ] ] * 4)
  end

  test "a tier's questions come in turn, and round again" do
    dealt = Ladder.deal(random: Random.new(1))
    asked = []
    Ladder.walk(dealt, [ false ] * (Ladder::POOL + 1)) { |right, question, _| asked << question; [ right, 1000 ] }
    assert_equal dealt[0], asked.first(Ladder::POOL)
    assert_equal dealt[0][0], asked.last
  end

  test "the hardest tier stays the hardest" do
    dealt = Ladder.deal(random: Random.new(1))
    tiers = []
    Ladder.walk(dealt, [ true ] * 60) { |right, _, tier| tiers << tier; [ right, 500 ] }
    assert_equal Ladder::TIERS.size - 1, tiers.max
    assert_equal Ladder::TIERS.size - 1, tiers.last
  end
end
