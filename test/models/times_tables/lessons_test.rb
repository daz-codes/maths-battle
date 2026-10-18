require "test_helper"

class TimesTables::LessonsTest < ActiveSupport::TestCase
  test "every level has a lesson of 3 or 4 steps, then one to try with a hint" do
    TimesTables.levels.each do |level|
      lesson = TimesTables.lesson(level[:number])
      assert_includes 3..4, lesson[:steps].size, "level #{level[:number]}"
      assert lesson[:steps].all? { _1[:show].present? && _1[:say].present? }
      assert lesson[:try].values_at(:question, :answer, :hint).all?(&:present?)
    end
  end

  test "each one to try has the right answer, typed as the game would want it" do
    TimesTables.levels.each do |level|
      try = TimesTables.lesson(level[:number])[:try]
      a, b = try[:question].tr("−", "-").split(" × ").map { BigDecimal(_1) }
      assert_equal TimesTables.written(a * b), try[:answer], try[:question]
    end
  end

  test "each answer can be typed with that level's keypad" do
    TimesTables.levels.each do |level|
      extra = try_answer(level[:number]).delete("0-9").chars
      assert_empty extra - TimesTables.keys(level[:number]), "level #{level[:number]} needs #{extra.inspect}"
    end
  end

  test "topics without lessons have none" do
    assert_nil Equations.lesson(1)
    assert_nil TimesTables.lesson(9)
  end

  private
    def try_answer(level) = TimesTables.lesson(level)[:try][:answer]
end
