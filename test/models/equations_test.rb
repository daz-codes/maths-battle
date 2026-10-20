require "test_helper"

class EquationsTest < ActiveSupport::TestCase
  def solve(type, a, b, c = nil) = Equations.written(Equations.solve({ type: type, a: a, b: b, c: c }))

  def answer(type, given, level: 5, **numbers)
    Equations.clean_result({ "type" => type, "v" => "x", "flip" => false, "given" => given, **numbers.stringify_keys }, level: level)
  end

  def sample(count = 2000, seed: 1, level: 5)
    random = Random.new(seed)
    Array.new(count) { Equations.question(Equations.facts(level).sample(random: random), level: level, random: random) }
  end

  test "fractions are written top-heavy in lowest terms" do
    assert_equal "3/4", solve("ax=b", 12, 9)
    assert_equal "11/9", solve("ax=b", 9, 11)
    assert_equal "4", solve("ax=b", 3, 12)
  end

  test "solves each type" do
    assert_equal "4", solve("x+a=b", 5, 9)
    assert_equal "11", solve("x-a=b", 3, 8)
    assert_equal "12", solve("x/a=b", 4, 3)
    assert_equal "2", solve("ax+b=c", 2, 7, 11)
    assert_equal "3", solve("ax-b=c", 5, 2, 13)
    assert_equal "12", solve("x/a+b=c", 3, 1, 5)
    assert_equal "9", solve("x/a-b=c", 3, 1, 2)
    assert_equal "11/2", solve("a(x+b)=c", 4, 2, 30)
    assert_equal "7", solve("(x+a)/b=c", 3, 5, 2)
  end

  test "every generated equation has a positive solution that scores as right" do
    sample.each do |question|
      assert_predicate Equations.solve(question), :positive?
      sent = question.except(:text, :answer).transform_keys(&:to_s).merge("given" => question[:answer])
      assert Equations.clean_result(sent, level: 5)["correct"], question.inspect
    end
  end

  test "each level is its own skill: two step at level 3, fraction answers at level 5" do
    assert_equal Equations::TWO_STEP.sort, sample(500, level: 3).map { _1[:type] }.uniq.sort
    assert_equal Equations::MULTIPLIED.sort, sample(500, level: 5).map { _1[:type] }.uniq.sort
    assert_operator sample(500, level: 5).count { _1[:answer].include?("/") }, :>, 300
  end

  test "covers every type, with some fractions, letters other than x, and some written the other way round" do
    questions = (1..5).flat_map { sample(400, level: _1) }
    assert_equal Equations::TYPES.keys.sort, questions.map { _1[:type] }.uniq.sort
    assert questions.any? { _1[:answer].include?("/") }
    assert_operator questions.map { _1[:v] }.uniq.size, :>, 5
    assert questions.any? { _1[:flip] }
  end

  test "an answer not in lowest terms is wrong" do
    assert answer("ax=b", "3/4", a: 12, b: 9)["correct"]
    assert_not answer("ax=b", "6/8", a: 12, b: 9)["correct"]
  end

  test "refuses questions the game couldn't have asked" do
    assert_raises(Attempt::Invalid) { answer("x^2=b", "2", a: 1, b: 4) }
    assert_raises(Attempt::Invalid) { Equations.clean_result({ "type" => "ax=b", "v" => "o", "a" => 2, "b" => 4, "given" => "2" }, level: 5) }
    assert_raises(Attempt::Invalid) { answer("x+a=b", "0", a: 5, b: 5) }
    assert_not answer("ax=b", "1/", a: 2, b: 1)["correct"], "unfinished, so just wrong"
    assert_raises(Attempt::Invalid) { answer("ax=b", "half", a: 2, b: 1) }
  end

  test "levels go from one step with small numbers to two step, bigger numbers, then fractions" do
    assert_equal Equations::ONE_STEP.sort, sample(500, level: 1).map { _1[:type] }.uniq.sort
    assert sample(500, level: 2).all? { Equations::ONE_STEP.include?(_1[:type]) }
    assert sample(500, level: 3).map { _1[:type] }.intersect?(Equations::TWO_STEP)
    assert sample(500, level: 4).map { _1[:type] }.intersect?(Equations::BRACKETS)
    assert sample(500, level: 1).none? { _1[:flip] }, "level 1 is always written the usual way round"
    assert (1..4).all? { |level| sample(500, level: level).none? { _1[:answer].include?("/") } }
    assert_operator sample(500, level: 2).map { _1[:a] }.max, :>, sample(500, level: 1).map { _1[:a] }.max
  end

  test "each level accepts its own and easier questions, but not harder ones" do
    assert answer("x+a=b", "4", level: 3, a: 5, b: 9)["correct"], "a one step question at the two step level"
    assert_raises(Attempt::Invalid) { answer("ax+b=c", "2", level: 2, a: 2, b: 7, c: 11) }
    assert_raises(Attempt::Invalid) { answer("ax=b", "3/4", level: 4, a: 12, b: 9) }
  end

  test "written out for the results page, with brackets where a fraction's top has two terms" do
    assert_equal "(h + 1)/3 = 4, so h = 11", Equations.label({ "type" => "(x+a)/b=c", "a" => 1, "b" => 3, "c" => 4, "v" => "h", "flip" => false })
    assert_equal "2 = m/3 − 1, so m = 9", Equations.label({ "type" => "x/a-b=c", "a" => 3, "b" => 1, "c" => 2, "v" => "m", "flip" => true })
  end

  test "the game shows fractions stacked, with the letter in italics" do
    text = Equations.question("x/a=b", random: Random.new(3))[:text]
    assert_match %r{<span class="frac"><span><var>\w</var></span><span>\d+</span></span> = \d+}, text
  end
end
