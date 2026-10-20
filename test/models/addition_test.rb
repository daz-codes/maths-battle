require "test_helper"

class AdditionTest < ActiveSupport::TestCase
  def answer(type, a, b, given, level: 5)
    Addition.clean_result({ "type" => type, "a" => a, "b" => b, "given" => given }, level: level)
  end

  def sample(level, count = 500, seed: 1)
    random = Random.new(seed)
    Array.new(count) { Addition.question(Addition.facts(level).sample(random: random), level: level, random: random) }
  end

  def numbers(level) = sample(level).flat_map { [ _1[:a], _1[:b] ] }

  test "single digits, two digits, three digits, round numbers, then decimals" do
    assert_equal [ "Single digits", "Two digits", "Three digits", "Zeroes", "Decimals" ], Addition.levels.map { _1[:name] }
    assert sample(1).select { _1[:type] == "add" }.all? { _1[:a].to_i <= 9 && _1[:b].to_i <= 9 }
    assert sample(1).select { _1[:type] == "subtract" }.all? { _1[:b].to_i <= 9 && _1[:answer].to_i <= 9 }, "undoing the adding facts"
    assert numbers(2).all? { _1.to_i < 100 }
    assert numbers(3).any? { _1.to_i >= 100 } && numbers(3).all? { _1.to_i < 1000 }
    assert numbers(4).all? { _1.end_with?("0") }
    assert numbers(5).all? { _1.include?(".") }
    assert sample(5).any? { _1[:a].split(".").last.size != _1[:b].split(".").last.size }, "mixed decimal places, like 2.3 − 0.32"
  end

  test "subtraction never goes below zero, and every question is one the server accepts" do
    (1..5).each do |level|
      sample(level).each do |question|
        assert_not question[:answer].start_with?("-"), question.inspect
        assert answer(question[:type], question[:a], question[:b], question[:answer], level: level)["correct"], question.inspect
      end
    end
  end

  test "exact decimals, typed with a decimal point only at the decimals level" do
    assert answer("subtract", "2.3", "0.32", "1.98")["correct"]
    assert_not answer("subtract", "2.3", "0.32", "1.980")["correct"]
    assert_equal [ [], [], [], [], [ "." ] ], (1..5).map { Addition.keys(_1) }
    assert_equal "2.3 − 0.32 = 1.98", Addition.label("type" => "subtract", "a" => "2.3", "b" => "0.32")
  end

  test "only numbers the level could have asked; a daily challenge's from easier levels are accepted" do
    assert answer("add", "7", "8", "15", level: 3)["correct"]
    assert_raises(Attempt::Invalid) { answer("add", "347", "285", "632", level: 2) }
    assert_raises(Attempt::Invalid) { answer("add", "2.3", "1", "3.3", level: 4) }
    assert_raises(Attempt::Invalid) { answer("subtract", "4", "9", "-5", level: 1) }
    assert_raises(Attempt::Invalid) { answer("divide", "8", "2", "4", level: 1) }
  end

  test "every lesson's one to try works out" do
    Addition::Lessons::ALL.each do |level, lesson|
      question = Addition.worked(lesson[:try][:question])
      assert answer(question[:type], question[:a], question[:b], question[:answer], level: level)["correct"], level
    end
  end
end
