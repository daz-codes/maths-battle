require "test_helper"

class PercentagesTest < ActiveSupport::TestCase
  def answer(type, a, b, given, level: 5)
    Percentages.clean_result({ "type" => type, "a" => a, "b" => b, "given" => given }, level: level)
  end

  def sample(count = 1000, seed: 1, level: 5)
    random = Random.new(seed)
    Array.new(count) { Percentages.question(Percentages.facts(level).sample(random: random), level: level, random: random) }
  end

  def percents(level) = sample(500, level: level).map { _1[:a] }.uniq.sort

  test "50% and 10%, then 5% and 25%, then combinations, then 1%, then any percentage" do
    assert_equal [ 10, 50 ], percents(1)
    assert_equal [ 5, 25 ], percents(2)
    assert percents(3).all? { (_1 % 5).zero? } && percents(3).include?(15) && percents(3).include?(95)
    assert_empty percents(3) & [ 5, 10, 25, 50 ]
    assert_equal [ 1 ], percents(4)
    assert_operator percents(5).size, :>, 50
  end

  test "every answer is whole, and the server agrees with it" do
    (1..5).each do |level|
      sample(500, level: level).each do |question|
        assert_equal 0, (question[:a] * question[:b]) % 100, question.inspect
        assert answer(question[:type], question[:a], question[:b], question[:answer], level: level)["correct"], question.inspect
      end
    end
    assert_empty Percentages.keys(5)
  end

  test "written as a percentage of a number" do
    assert_equal({ type: "fives", a: 15, b: 60, text: "15% of 60", answer: "9" }, Percentages.worked(type: "fives", a: 15, b: 60))
    assert_equal "37% of 300 = 111", Percentages.label("type" => "any", "a" => 37, "b" => 300)
  end

  test "a level's practice asks only its own; a daily challenge's from easier levels are accepted" do
    assert sample(300, level: 4).all? { _1[:type] == "1" }
    assert answer("50", 50, 60, "30", level: 4)["correct"]
    assert_raises(Attempt::Invalid) { answer("any", 37, 300, "111", level: 4) }
  end

  test "questions it couldn't have asked are refused" do
    assert_raises(Attempt::Invalid) { answer("10", 15, 60, "9", level: 1) }
    assert_raises(Attempt::Invalid) { answer("5", 5, 30, "1.5", level: 2) }
    assert_raises(Attempt::Invalid) { answer("1", 1, 250, "2.5", level: 4) }
    assert_raises(Attempt::Invalid) { answer("any", 37, 99_900, "36963") }
  end

  test "every lesson's one to try works out" do
    Percentages::Lessons::ALL.each do |level, lesson|
      question = Percentages.worked(lesson[:try][:question])
      assert answer(question[:type], question[:a], question[:b], question[:answer], level: level)["correct"], level
    end
  end
end
