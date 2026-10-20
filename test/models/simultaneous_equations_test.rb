require "test_helper"

class SimultaneousEquationsTest < ActiveSupport::TestCase
  T = SimultaneousEquations

  # 3x + 5y = 11 and 2x + 5y = 9: subtracting leaves x = 2, then y = 1
  PAIR = { "type" => "subtract", "a" => 3, "b" => 5, "c" => 11, "d" => 2, "e" => 5, "f" => 9 }

  def answer(given, v: "x", level: 5, **pair)
    T.clean_result(PAIR.merge(pair.stringify_keys).merge("v" => v, "given" => given), level: level)
  end

  def sample(count = 500, seed: 1, level: 5)
    random = Random.new(seed)
    Array.new(count) { T.questions_for(T.facts(level).sample(random: random), level: level, random: random) }.flatten
  end

  def sent(question) = question.except(:text, :answer).transform_keys(&:to_s).merge("given" => question[:answer])
  def totals(questions) = questions.flat_map { _1.values_at(:c, :f) }

  test "each pair is asked for x, then for y" do
    x, y = T.questions_for("subtract", random: Random.new(2))
    assert_equal %w[ x y ], [ x[:v], y[:v] ]
    assert_equal x.except(:v, :text, :answer), y.except(:v, :text, :answer), "the same pair both times"
    assert_includes y[:text], %(<span class="system__known"><var>x</var> = #{x[:answer]}</span>), "with x given"
    assert_not_includes x[:text], "system__known"
  end

  test "solves the pair" do
    assert_equal({ "x" => 2, "y" => 1 }, T.solution(PAIR.transform_keys(&:to_sym)))
    assert answer("2")["correct"]
    assert answer("1", v: "y")["correct"]
    assert_not answer("1")["correct"]
  end

  test "every generated pair has a whole solution from 1 to 5 that scores as right" do
    every_level = (1..5).flat_map { sample(300, level: _1) }
    every_level.each do |question|
      assert T.clean_result(sent(question), level: 5)["correct"], question.inspect
      assert_includes 1..5, question[:answer].to_i
    end
    assert_equal T::TYPES.keys.sort, every_level.map { _1[:type] }.uniq.sort
  end

  test "level 1: everything positive, the y terms match, and subtracting leaves x itself" do
    sample(300, level: 1).each do |question|
      assert question.values_at(:a, :b, :c, :d, :e, :f).all?(&:positive?), question.inspect
      assert_equal question[:b], question[:e]
      assert_equal 1, (question[:a] - question[:d]).abs
    end
  end

  test "small enough to work out in your head" do
    assert totals(sample(300, level: 1)).all? { _1 <= 20 }
    assert totals(sample(300, level: 3)).all? { _1.abs <= 20 }
    assert totals(sample(300, level: 5)).all? { _1.abs <= 25 }
    assert sample(300, level: 5).flat_map { _1.values_at(:a, :b, :d, :e) }.all? { _1.abs <= 6 }
  end

  test "levels go from subtracting, to subtracting and dividing, adding, a mixture, then doubling one" do
    assert_equal [ "subtract and divide" ], sample(200, level: 2).map { _1[:type] }.uniq
    assert sample(200, level: 2).all? { _1.values_at(:c, :f).all?(&:positive?) }
    assert_equal [ "add" ], sample(200, level: 3).map { _1[:type] }.uniq
    assert sample(200, level: 4).any? { _1[:type] != "add" && _1[:b].negative? }, "negative terms beyond adding"
    assert sample(200, level: 4).none? { _1[:type] == "multiply" }
    assert_equal [ "multiply" ], sample(200, level: 5).map { _1[:type] }.uniq
  end

  test "doubling one equation leaves a small multiple of x" do
    sample(300, level: 5).select { _1[:type] == "multiply" }.each do |question|
      a, b, d, e = question.values_at(:a, :b, :d, :e)
      a, b, d, e = d, e, a, b if b.abs > e.abs
      assert_includes 1..4, (2 * b == e ? 2 * a - d : 2 * a + d).abs, question.inspect
    end
  end

  test "each level accepts its own and easier ways of solving, but not harder ones" do
    assert answer("2", level: 2)["correct"]
    # 5x + 2y = 16 and 2x + 2y = 10: 3x = 6
    assert_raises(Attempt::Invalid) { answer("2", level: 1, type: "subtract and divide", a: 5, b: 2, c: 16, d: 2, e: 2, f: 10) }
    # x + y = 5 and 3x + 2y = 12
    assert_raises(Attempt::Invalid) { answer("2", level: 4, type: "multiply", a: 1, b: 1, c: 5, d: 3, e: 2, f: 12) }
  end

  test "refuses pairs the game couldn't have asked" do
    assert_raises(Attempt::Invalid) { answer("2", type: "add") }
    assert_raises(Attempt::Invalid) { answer("2", type: "multiply both") }
    assert_raises(Attempt::Invalid) { answer("2", v: "z") }
    assert_raises(Attempt::Invalid) { answer("2", c: 12) }
    # 4x + 3y = 31 and 2x + 3y = 17: x = 7, which is out of range
    assert_raises(Attempt::Invalid) { answer("7", type: "subtract and divide", a: 4, b: 3, c: 31, d: 2, e: 3, f: 17) }
    assert_not answer("2.5")["correct"], "an answer the keypad could type is just wrong"
    assert_raises(Attempt::Invalid) { answer("two") }
  end

  test "written out for the results page, including pairs from before the levels changed" do
    assert_equal "3x + 5y = 11 and 2x + 5y = 9, so x = 2", T.label(PAIR.merge("v" => "x"))
    assert_equal "2x + 3y = 13 and x − 3y = −7, so y = 3", T.label({ "type" => "add", "a" => 2, "b" => 3, "c" => 13, "d" => 1, "e" => -3, "f" => -7, "v" => "y" })
    assert_equal "3x + 4y = 13 and 2x + y = 7, so y = 1", T.label({ "type" => "multiply both", "a" => 3, "b" => 4, "c" => 13, "d" => 2, "e" => 1, "f" => 7, "v" => "y" })
  end

  test "the game lines the equations up in columns" do
    text = T.questions_for("subtract", random: Random.new(2)).first[:text]
    assert_equal 2, text.scan('<span class="system__row">').size
    assert_match %r{<span class="system__ask"><var>x</var> =</span>\z}, text
  end
end
