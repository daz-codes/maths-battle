require "test_helper"

# Every topic has a lesson for each level, and its one to try is a real question the level asks
class LessonsTest < ActiveSupport::TestCase
  def each_lesson
    Topic::ALL.each do |topic|
      topic.levels.each { |level| yield topic, level[:number], topic.lesson(level[:number]) }
    end
  end

  test "every level of every topic has a lesson of 3 or 4 steps, then one to try with a hint" do
    each_lesson do |topic, level, lesson|
      assert lesson, "#{topic.title} level #{level}"
      assert_includes 3..4, lesson[:steps].size, "#{topic.title} level #{level}"
      assert lesson[:steps].all? { Array(_1[:show]).all?(&:present?) && _1[:say].present? }
      assert lesson[:try].values_at(:question, :hint).all?(&:present?)
    end
  end

  test "each one to try is a question its level asks, and the topic's answer is right" do
    each_lesson do |topic, level, lesson|
      worked = topic.worked(lesson[:try][:question])
      sent = worked.except(:text, :answer).transform_keys(&:to_s).merge("given" => worked[:answer])
      assert topic.clean_result(sent, level: level)["correct"], "#{topic.title} level #{level}"
    end
  end

  test "each answer can be typed with that level's keypad" do
    each_lesson do |topic, level, lesson|
      extra = topic.worked(lesson[:try][:question])[:answer].delete("0-9").chars
      assert_empty extra - topic.keys(level), "#{topic.title} level #{level} needs #{extra.inspect}"
    end
  end

  test "no lesson for a level that isn't there" do
    assert_nil TimesTables.lesson(9)
  end
end
