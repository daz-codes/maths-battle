require "test_helper"

class FractionsTest < ActiveSupport::TestCase
  def answer(type, given, level: 5, **numbers)
    Fractions.clean_result({ "type" => type, "given" => given, **numbers.stringify_keys }, level: level)
  end

  def sample(count = 2000, seed: 1, level: 5)
    random = Random.new(seed)
    Array.new(count) { Fractions.question(Fractions.facts(level).sample(random: random), level: level, random: random) }
  end

  def sent(question) = question.except(:text, :answer).transform_keys(&:to_s).merge("given" => question[:answer])

  test "each level is its own skill: simplifying, same denominators, different ones, multiplying, dividing" do
    assert_equal [ %w[ simplify ], %w[ add-same sub-same ], %w[ add-diff sub-diff ], %w[ multiply ], %w[ divide ] ],
      (1..5).map { Fractions.facts(_1) }
    assert_equal [ "Simplifying", "Same denominators", "Different denominators", "Multiplying", "Dividing" ], Fractions.levels.map { _1[:name] }
  end

  test "answers are in lowest terms: top-heavy when more than one, and whole numbers on their own" do
    assert answer("simplify", "3/4", level: 1, a: 6, b: 8)["correct"]
    assert_not answer("simplify", "6/8", level: 1, a: 6, b: 8)["correct"], "not simplified"
    assert answer("add-same", "1/2", level: 2, a: 3, b: 8, c: 1, d: 8)["correct"]
    assert_not answer("add-same", "4/8", level: 2, a: 3, b: 8, c: 1, d: 8)["correct"]
    assert answer("add-diff", "7/12", level: 3, a: 1, b: 3, c: 1, d: 4)["correct"]
    assert answer("sub-diff", "7/12", level: 3, a: 3, b: 4, c: 1, d: 6)["correct"]
    assert answer("multiply", "2/5", level: 4, a: 2, b: 3, c: 3, d: 5)["correct"]
    assert answer("divide", "3/2", level: 5, a: 3, b: 4, c: 1, d: 2)["correct"]
    assert answer("divide", "3", level: 5, a: 1, b: 2, c: 1, d: 6)["correct"]
    assert answer("add-same", "1", level: 2, a: 3, b: 6, c: 3, d: 6)["correct"]
  end

  test "every generated question is one the server accepts, answered as it says" do
    (1..5).each do |level|
      sample(500, level: level).each { |question| assert Fractions.clean_result(sent(question), level: level)["correct"], question.inspect }
    end
  end

  test "questions are kind to mental maths: proper fractions, small common denominators, no subtraction below zero" do
    sample(1000, level: 3).each do |question|
      assert_operator question[:b].lcm(question[:d]), :<=, Fractions::MAX_COMMON_DENOMINATOR
      assert question[:a] < question[:b] && question[:c] < question[:d]
    end
    sample(1000, level: 1).each { |question| assert_operator question[:a].gcd(question[:b]), :>, 1, "always simplifies" }
  end

  test "a level's practice asks only its own; a daily challenge's questions from easier levels are accepted" do
    assert sample(500, level: 4).all? { _1[:type] == "multiply" }
    assert answer("simplify", "3/4", level: 4, a: 6, b: 8)["correct"]
    assert_raises(Attempt::Invalid) { answer("multiply", "2/5", level: 3, a: 2, b: 3, c: 3, d: 5) }
  end

  test "questions it couldn't have asked are refused" do
    assert_raises(Attempt::Invalid) { answer("simplify", "3/4", level: 1, a: 3, b: 4) }
    assert_raises(Attempt::Invalid) { answer("sub-same", "0", level: 2, a: 2, b: 5, c: 3, d: 5) }
    assert_raises(Attempt::Invalid) { answer("add-same", "1", level: 2, a: 1, b: 3, c: 1, d: 4) }
    assert_raises(Attempt::Invalid) { answer("add-diff", "1", level: 3, a: 1, b: 4, c: 1, d: 4) }
    assert_raises(Attempt::Invalid) { answer("multiply", "1", level: 4, a: 5, b: 4, c: 1, d: 2) }
    assert_raises(Attempt::Invalid) { answer("divide", "1", level: 5, a: 0, b: 4, c: 1, d: 2) }
  end

  test "stacked in the game, on one line on the results page, with a fraction line on the keypad" do
    question = Fractions.worked(type: "add-diff", a: 1, b: 3, c: 1, d: 4)
    assert_equal %(<span class="frac"><span>1</span><span>3</span></span> + <span class="frac"><span>1</span><span>4</span></span>), question[:text]
    assert_match(/\A<span class="question__verb">Simplify<\/span>/, Fractions.worked(type: "simplify", a: 6, b: 8)[:text])
    assert_equal "1/3 + 1/4 = 7/12", Fractions.label("type" => "add-diff", "a" => 1, "b" => 3, "c" => 1, "d" => 4)
    assert_equal [ "/" ], Fractions.keys(1)
  end

  test "every lesson's one to try works out" do
    Fractions::Lessons::ALL.each do |level, lesson|
      question = Fractions.worked(lesson[:try][:question])
      assert Fractions.clean_result(sent(question), level: level)["correct"], level
    end
  end
end
