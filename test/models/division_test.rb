require "test_helper"

class DivisionTest < ActiveSupport::TestCase
  def answer(a, b, given, level: 5)
    Division.clean_result({ "a" => a, "b" => b, "given" => given }, level: level)
  end

  def sample(count = 1000, seed: 1, level: 5)
    random = Random.new(seed)
    Array.new(count) { Division.question(Division.facts(level).sample(random: random), level: level, random: random) }
  end

  test "times tables the other way round, at the same levels" do
    assert_equal TimesTables.levels.map { _1[:name] }, Division.levels.map { _1[:name] }
    assert_equal({ a: "56", b: "8", text: "56 ÷ 8", answer: "7" }, Division.worked(a: 56, b: 8))
    assert_equal "7x8", Division.fact_key("a" => "5.6", "b" => "0.8")
    assert_equal [ 7, 8 ], Division.groups_of("7x8")
  end

  test "every generated question divides exactly, and the server agrees with its answer" do
    (1..5).each do |level|
      sample(500, level: level).each do |question|
        assert answer(question[:a], question[:b], question[:answer], level: level)["correct"], question.inspect
      end
    end
  end

  test "zeroes, then decimals only, then both" do
    assert sample(300, level: 2).all? { "#{_1[:a]}#{_1[:b]}".exclude?(".") }
    assert sample(300, level: 3).all? { "#{_1[:text]}#{_1[:answer]}".exclude?(".") }
    assert sample(300, level: 4).any? { _1[:text].include?(".") }
    assert sample(300, level: 4).none? { |question| [ question[:b], question[:answer] ].any? { _1.match?(/\A\d+00\z/) } }, "no zeroes"
    assert sample(300, level: 5).any? { |question| [ question[:b], question[:answer] ].any? { _1.end_with?("00") } }
    assert_equal [ "." ], Division.keys(4)
    assert_empty Division.keys(3)
  end

  test "only questions the level could have asked, that come out exactly" do
    assert_raises(Attempt::Invalid) { answer("57", "8", "7", level: 2) }
    assert_raises(Attempt::Invalid) { answer("2100", "0.7", "3000", level: 4) }
    assert_raises(Attempt::Invalid) { answer("48", "6", "8", level: 1) }
    assert_raises(Attempt::Invalid) { answer("-56", "8", "-7", level: 5) }
    assert_not answer("56", "8", "8", level: 2)["correct"]
  end

  test "every lesson's one to try works out" do
    Division::Lessons::ALL.each do |level, lesson|
      question = Division.worked(lesson[:try][:question])
      assert answer(question[:a], question[:b], question[:answer], level: level)["correct"], level
    end
  end
end
