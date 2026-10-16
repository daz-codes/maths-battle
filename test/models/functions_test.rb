require "test_helper"

class FunctionsTest < ActiveSupport::TestCase
  def value(type, **numbers) = Functions.value({ type: type, **numbers })

  def answer(type, given, level: 5, **numbers)
    Functions.clean_result({ "type" => type, "given" => given, **numbers.stringify_keys }, level: level)
  end

  def sample(count = 2000, seed: 1, level: 5)
    random = Random.new(seed)
    Array.new(count) { Functions.question(Functions.facts(level).sample(random: random), level: level, random: random) }
  end

  def sent(question) = question.except(:text, :answer).transform_keys(&:to_s).merge("given" => question[:answer])

  test "works out each form" do
    assert_equal 9, value("x+a", a: 5, n: 4)
    assert_equal 1, value("x-a", a: 3, n: 4)
    assert_equal 12, value("ax", a: 3, n: 4)
    assert_equal 11, value("ax+b", a: 2, b: 3, n: 4)
    assert_equal 11, value("ax-b", a: 3, b: 1, n: 4)
    assert_equal 2, value("x/a+b", a: 2, b: 5, n: -6)
    assert_equal 11, value("x^2-a", a: 5, n: -4)
    assert_equal 27, value("ax^2", a: 3, n: -3)
    assert_equal 1, value("(x+a)^2", a: 2, n: -3)
  end

  test "composites work inside out, and inverses undo the function" do
    # f(x) = 2x + 1, g(x) = x − 3
    assert_equal 5, value("f(g(x))", a: 2, b: 1, c: 1, d: -3, n: 5)
    assert_equal 8, value("g(f(x))", a: 2, b: 1, c: 1, d: -3, n: 5)
    # f(x) = 3x − 2: f⁻¹(10) = 4. f(x) = x/2 + 3: f⁻¹(7) = 8
    assert_equal 4, value("inv:ax+b", a: 3, b: -2, n: 10)
    assert_equal 8, value("inv:x/a+b", a: 2, b: 3, n: 7)
  end

  test "every generated question has a whole number answer that scores as right" do
    sample.each { |question| assert Functions.clean_result(sent(question), level: 5)["correct"], question.inspect }
    assert_equal Functions::TYPES.keys.sort, sample.map { _1[:type] }.uniq.sort
  end

  test "levels go from linear, to negatives, squares, composites, then inverses" do
    assert_equal Functions::LINEAR.sort, sample(500, level: 1).map { _1[:type] }.uniq.sort
    assert sample(500, level: 1).all? { _1[:answer].to_i.positive? && _1[:n].positive? }, "level 1 has no negatives, so no minus key"
    assert sample(500, level: 2).any? { _1[:n].negative? }
    assert sample(500, level: 3).map { _1[:type] }.intersect?(Functions::SQUARES)
    assert sample(500, level: 4).map { _1[:type] }.intersect?(Functions::COMPOSITE)
    assert sample(500, level: 4).none? { Functions::INVERSE.include?(_1[:type]) }
    assert sample(500, level: 5).map { _1[:type] }.intersect?(Functions::INVERSE)
  end

  test "a minus key from level 2" do
    assert_empty Functions.keys(1)
    assert_equal [ "-" ], Functions.keys(2)
  end

  test "negative answers are typed with a minus" do
    assert answer("x-a", "-3", level: 2, a: 5, n: 2)["correct"]
    assert_not answer("x-a", "3", level: 2, a: 5, n: 2)["correct"]
  end

  test "each level accepts its own and easier questions, but not harder ones" do
    assert answer("ax+b", "11", level: 4, a: 2, b: 3, n: 4)["correct"]
    assert_raises(Attempt::Invalid) { answer("x^2+a", "20", level: 2, a: 4, n: 4) }
    assert_raises(Attempt::Invalid) { answer("inv:ax+b", "4", level: 4, a: 3, b: -2, n: 10) }
    assert_raises(Attempt::Invalid) { answer("x+a", "2", level: 1, a: 5, n: -3) }
  end

  test "refuses questions the game couldn't have asked" do
    assert_raises(Attempt::Invalid) { answer("x^3", "8", n: 2, a: 1) }
    assert_raises(Attempt::Invalid) { answer("x/a+b", "3", a: 2, b: 1, n: 5) }
    assert_raises(Attempt::Invalid) { answer("inv:ax+b", "3", a: 3, b: 1, n: 9) }
    assert_raises(Attempt::Invalid) { answer("ax", "0", a: 0, n: 4) }
    assert_raises(Attempt::Invalid) { answer("ax+b", "1.5", a: 2, b: 3, n: 4) }
    assert_raises(Attempt::Invalid) { answer("ax+b", "11", a: 2, b: 3, n: 4000) }
  end

  test "written out for the results page" do
    assert_equal "f(x) = 2x + 3, so f(4) = 11", Functions.label({ "type" => "ax+b", "a" => 2, "b" => 3, "n" => 4 })
    assert_equal "f(x) = 2x + 1 and g(x) = x − 3, so f(g(5)) = 5", Functions.label({ "type" => "f(g(x))", "a" => 2, "b" => 1, "c" => 1, "d" => -3, "n" => 5 })
    assert_equal "f(x) = 3x − 2, so f⁻¹(10) = 4", Functions.label({ "type" => "inv:ax+b", "a" => 3, "b" => -2, "n" => 10 })
    assert_equal "f(x) = x/2 + 5, so f(−6) = 2", Functions.label({ "type" => "x/a+b", "a" => 2, "b" => 5, "n" => -6 })
  end

  test "the game shows each function on its own line, then what's asked" do
    text = Functions.question("f(g(x))", level: 4, random: Random.new(3))[:text]
    assert_equal 3, text.scan('<span class="function').size
    assert_match %r{<span class="function function--ask"><var>f</var>\(<var>g</var>\(−?\d+\)\)</span>\z}, text
  end
end
