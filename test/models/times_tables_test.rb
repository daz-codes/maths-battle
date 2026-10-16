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
    assert TimesTables.clean_result({ "a" => 7, "b" => 8, "given" => "56" })["correct"]
    assert_not TimesTables.clean_result({ "a" => 7, "b" => 8, "given" => "54" })["correct"]
    assert_raises(Attempt::Invalid) { TimesTables.clean_result({ "a" => 13, "b" => 8, "given" => "104" }) }
  end

  test "groups are the tables, and 7×8 belongs to both" do
    assert_equal [ 7, 8 ], TimesTables.groups_of("7x8")
    assert_equal [ 7 ], TimesTables.groups_of("7x7")
    assert_equal "Practise your 7× and 8× tables", TimesTables.practise_message([ 7, 8 ])
  end
end
