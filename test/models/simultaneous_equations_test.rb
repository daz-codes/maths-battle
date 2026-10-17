require "test_helper"

class SimultaneousEquationsTest < ActiveSupport::TestCase
  T = SimultaneousEquations

  # 2x + 3y = 13 and 2x + y = 7: x = 2, y = 3
  PAIR = { "type" => "subtract", "a" => 2, "b" => 3, "c" => 13, "d" => 2, "e" => 1, "f" => 7 }

  def answer(given, v: "y", level: 5, **pair)
    T.clean_result(PAIR.merge(pair.stringify_keys).merge("v" => v, "given" => given), level: level)
  end

  def sample(count = 500, seed: 1, level: 5)
    random = Random.new(seed)
    Array.new(count) { T.questions_for(T.facts(level).sample(random: random), level: level, random: random) }.flatten
  end

  def sent(question) = question.except(:text, :answer).transform_keys(&:to_s).merge("given" => question[:answer])

  test "each pair is asked for y, then for x" do
    y, x = T.questions_for("subtract", random: Random.new(2))
    assert_equal %w[ y x ], [ y[:v], x[:v] ]
    assert_equal y.except(:v, :text, :answer), x.except(:v, :text, :answer), "the same pair both times"
    assert_includes x[:text], %(<span class="system__known"><var>y</var> = #{y[:answer]}</span>), "with y given"
    assert_not_includes y[:text], "system__known"
  end

  test "solves the pair" do
    assert_equal({ "x" => 2, "y" => 3 }, T.solution(PAIR.transform_keys(&:to_sym)))
    assert answer("3")["correct"]
    assert answer("2", v: "x")["correct"]
    assert_not answer("2")["correct"]
  end

  test "every generated pair has a whole solution from 1 to 9 that scores as right" do
    sample.each do |question|
      assert T.clean_result(sent(question), level: 5)["correct"], question.inspect
      assert_includes 1..9, question[:answer].to_i
    end
    assert_equal T::TYPES.keys.sort, sample.map { _1[:type] }.uniq.sort
  end

  test "the x terms cancel the way the type says" do
    sample.each do |question|
      a, d = question.values_at(:a, :d)
      case question[:type]
      when "subtract" then assert_equal a, d
      when "add" then assert_equal a, -d
      when "multiply one" then assert (d % a).zero? || (a % d).zero?
      when "multiply both" then assert_not (d % a).zero? || (a % d).zero?
      end
    end
  end

  test "levels go from subtracting, to adding, a mixture, then multiplying one or both" do
    assert sample(200, level: 1).all? { _1[:type] == "subtract" && _1.values_at(:a, :b, :c, :d, :e, :f).all?(&:positive?) }
    assert_includes sample(200, level: 2).map { _1[:type] }, "add"
    assert sample(200, level: 3).any? { _1[:b].negative? || _1[:e].negative? }, "some y terms are negative"
    assert_includes sample(200, level: 4).map { _1[:type] }, "multiply one"
    assert sample(200, level: 4).none? { _1[:type] == "multiply both" }
    assert_includes sample(200, level: 5).map { _1[:type] }, "multiply both"
    assert sample(200, level: 5).all? { _1[:answer].to_i <= 6 }, "smaller solutions once equations need multiplying"
  end

  test "each level accepts its own and easier ways of solving, but not harder ones" do
    assert answer("3", level: 2)["correct"]
    # 2x + 3y = 12 and 4x + y = 14: x = 3, y = 2
    assert_raises(Attempt::Invalid) { answer("2", level: 3, type: "multiply one", a: 2, b: 3, c: 12, d: 4, e: 1, f: 14) }
  end

  test "refuses pairs the game couldn't have asked" do
    assert_raises(Attempt::Invalid) { answer("3", type: "add") }
    assert_raises(Attempt::Invalid) { answer("3", v: "z") }
    assert_raises(Attempt::Invalid) { answer("1", c: 14) }
    assert_raises(Attempt::Invalid) { answer("1", d: 4, e: 6, f: 26) }
    assert_raises(Attempt::Invalid) { answer("3.5") }
  end

  test "written out for the results page" do
    assert_equal "2x + 3y = 13 and 2x + y = 7, so y = 3", T.label(PAIR.merge("v" => "y"))
    assert_equal "2x − 3y = 1 and −2x + y = −3, so x = 2", T.label({ "type" => "add", "a" => 2, "b" => -3, "c" => 1, "d" => -2, "e" => 1, "f" => -3, "v" => "x" })
  end

  test "the game lines the equations up in columns" do
    text = T.questions_for("subtract", random: Random.new(2)).first[:text]
    assert_equal 2, text.scan('<span class="system__row">').size
    assert_match %r{<span class="system__ask"><var>y</var> =</span>\z}, text
  end
end
