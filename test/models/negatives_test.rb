require "test_helper"

class NegativesTest < ActiveSupport::TestCase
  def answer(type, a, b, given, level: 5)
    Negatives.clean_result({ "type" => type, "a" => a, "b" => b, "given" => given }, level: level)
  end

  def sample(count = 1000, seed: 1, level: 5)
    random = Random.new(seed)
    Array.new(count) { Negatives.question(Negatives.facts(level).sample(random: random), level: level, random: random) }
  end

  test "each level its own skill: below zero, starting below zero, adding negatives, subtracting them, × and ÷" do
    assert_equal [ %w[ below-zero ], %w[ below-zero from-negative ], %w[ add-negative ], %w[ subtract-negative ], %w[ multiply divide ] ],
      (1..5).map { Negatives.facts(_1) }
  end

  test "written with proper minus signs, and a negative second number in brackets" do
    assert_equal "4 − 9", Negatives.worked(type: "below-zero", a: 4, b: 9)[:text]
    assert_equal "−2 − 9", Negatives.worked(type: "from-negative", a: -2, b: -9)[:text]
    assert_equal "−4 + 2", Negatives.worked(type: "from-negative", a: -4, b: 2)[:text]
    assert_equal "−3 + (−4)", Negatives.worked(type: "add-negative", a: -3, b: -4)[:text]
    assert_equal "−5 − (−7)", Negatives.worked(type: "subtract-negative", a: -5, b: -7)[:text]
    assert_equal "−24 ÷ (−6)", Negatives.worked(type: "divide", a: -24, b: -6)[:text]
    assert_equal "−5 − (−7) = 2", Negatives.label("type" => "subtract-negative", "a" => -5, "b" => -7)
  end

  test "answered with a minus key: negative answers have one, positive ones don't" do
    assert_equal [ "-" ], Negatives.keys(1)
    assert answer("below-zero", 4, 9, "-5", level: 1)["correct"]
    assert_not answer("below-zero", 4, 9, "5", level: 1)["correct"]
    assert answer("subtract-negative", -5, -7, "2", level: 4)["correct"]
    assert answer("divide", -24, -6, "4")["correct"]
    assert answer("multiply", -6, 4, "-24")["correct"]
  end

  test "every generated question is one the server accepts, answered as it says" do
    (1..5).each do |level|
      sample(500, level: level).each do |question|
        assert answer(question[:type], question[:a], question[:b], question[:answer], level: level)["correct"], question.inspect
      end
    end
  end

  test "level 1 always goes below zero; dividing always comes out whole" do
    assert sample(300, level: 1).all? { _1[:answer].start_with?("-") }
    assert sample(500).select { _1[:type] == "divide" }.all? { (_1[:a] % _1[:b]).zero? }
  end

  test "a level's practice asks only its own; a daily challenge's from easier levels are accepted" do
    assert sample(300, level: 3).all? { _1[:type] == "add-negative" }
    assert answer("below-zero", 4, 9, "-5", level: 3)["correct"]
    assert_raises(Attempt::Invalid) { answer("multiply", -6, 4, "-24", level: 4) }
  end

  test "questions it couldn't have asked are refused" do
    assert_raises(Attempt::Invalid) { answer("below-zero", 9, 4, "5", level: 1) }
    assert_raises(Attempt::Invalid) { answer("from-negative", 4, 2, "6", level: 2) }
    assert_raises(Attempt::Invalid) { answer("add-negative", -3, 4, "1", level: 3) }
    assert_raises(Attempt::Invalid) { answer("divide", -25, 6, "-4") }
    assert_raises(Attempt::Invalid) { answer("multiply", 6, 4, "24") }
  end

  test "every lesson's one to try works out" do
    Negatives::Lessons::ALL.each do |level, lesson|
      question = Negatives.worked(lesson[:try][:question])
      assert answer(question[:type], question[:a], question[:b], question[:answer], level: level)["correct"], level
    end
  end
end
