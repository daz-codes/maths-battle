require "test_helper"

class TimesTablesTest < ActiveSupport::TestCase
  test "facts are normalised so both orders share a key" do
    assert_equal "7x8", TimesTables.fact_key({ "a" => 7, "b" => 8 })
    assert_equal "7x8", TimesTables.fact_key({ "a" => 8, "b" => 7 })
    assert_equal "3x12", TimesTables.fact_key({ "a" => 12, "b" => 3 })
  end

  test "questions carry their text and answer" do
    question = TimesTables.question("7x8", random: Random.new(1))
    assert_includes [ %w[ 7 8 ], %w[ 8 7 ] ], question.values_at(:a, :b)
    assert_equal "56", question[:answer]
    assert_match(/\A[78] × [78]\z/, question[:text])
  end

  test "answers are checked on the server, and questions must be within the tables" do
    assert TimesTables.clean_result({ "a" => 7, "b" => 8, "given" => "56" }, level: 2)["correct"]
    assert_not TimesTables.clean_result({ "a" => 7, "b" => 8, "given" => "54" }, level: 2)["correct"]
    assert_raises(Attempt::Invalid) { TimesTables.clean_result({ "a" => 13, "b" => 8, "given" => "104" }, level: 2) }
  end

  test "level 1 only takes the 2–5 tables" do
    assert TimesTables.clean_result({ "a" => 12, "b" => 5, "given" => "60" }, level: 1)["correct"]
    assert_raises(Attempt::Invalid) { TimesTables.clean_result({ "a" => 12, "b" => 12, "given" => "144" }, level: 1) }
    assert_raises(Attempt::Invalid) { TimesTables.clean_result({ "a" => 7, "b" => 8, "given" => "56" }, level: 1) }
  end

  test "groups are the tables, and 7×8 belongs to both" do
    assert_equal [ 7, 8 ], TimesTables.groups_of("7x8")
    assert_equal [ 7 ], TimesTables.groups_of("7x7")
    assert_equal "Practise your 7× and 8× tables", TimesTables.practise_message([ 7, 8 ])
  end

  def sample(level, count = 500, seed: 1)
    random = Random.new(seed)
    Array.new(count) { TimesTables.question(TimesTables.facts(level).sample(random: random), level: level, random: random) }
  end

  test "levels: tables, zeroes, decimals only, then zeroes and decimals, and never negatives" do
    assert_equal [ "Tables 2–5", "Tables 2–12", "Zeroes", "Decimals", "Zeroes and decimals" ], TimesTables.levels.map { _1[:name] }
    assert sample(3).none? { _1[:text].include?(".") }
    assert sample(4).all? { |question| [ question[:a], question[:b] ].none? { _1.match?(/\A\d+0\z/) && _1 != "10" } }, "decimals only, no zeroes"
    assert sample(4).any? { _1[:text].include?(".") }
    assert sample(5).any? { |question| [ question[:a], question[:b] ].any? { _1.include?(".") } && [ question[:a], question[:b] ].any? { _1.end_with?("00") } }
    assert (1..5).flat_map { sample(_1, 200) }.none? { "#{_1[:text]}#{_1[:answer]}".match?(/[−-]/) }
    assert_equal [ [], [], [], [ "." ], [ "." ] ], (1..5).map { TimesTables.keys(_1) }
  end

  test "every generated question is one the server accepts" do
    (1..5).each do |level|
      sample(level).each do |question|
        assert TimesTables.clean_result({ "a" => question[:a], "b" => question[:b], "given" => question[:answer] }, level: level)["correct"], question.inspect
      end
    end
  end
end
