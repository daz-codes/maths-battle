require "test_helper"

class TimesTablesTest < ActiveSupport::TestCase
  test "facts are normalised so both orders share a key" do
    assert_equal "7x8", TimesTables.fact_key(7, 8)
    assert_equal "7x8", TimesTables.fact_key(8, 7)
    assert_equal "3x12", TimesTables.fact_key(12, 3)
  end

  test "questions are within the tables" do
    assert TimesTables.valid_question?(1, 12)
    assert_not TimesTables.valid_question?(0, 5)
    assert_not TimesTables.valid_question?(13, 5)
  end
end
