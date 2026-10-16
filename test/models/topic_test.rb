require "test_helper"

class TopicTest < ActiveSupport::TestCase
  test "every topic answers the same questions about itself" do
    assert_equal [ "times_tables", "times-tables", "Times tables", "✖️" ], [ TimesTables.key, TimesTables.slug, TimesTables.title, TimesTables.emoji ]
    assert_equal [ "equations", "equations", "Equations", "⚖️" ], [ Equations.key, Equations.slug, Equations.title, Equations.emoji ]
  end

  test "levels are found by number" do
    assert_equal "Zeroes", TimesTables.level(3)[:name]
    assert_nil TimesTables.level(6)
    assert_equal 5, Equations.max_level
  end

  test "topics are found by key or slug" do
    assert_equal TimesTables, Topic.find("times_tables")
    assert_equal TimesTables, Topic.find_by_slug("times-tables")
    assert_nil Topic.find("spelling")
    assert_equal %w[ times_tables equations ], Topic.keys
  end

  test "a topic keeps its own module name" do
    assert_equal "TimesTables", TimesTables.name
  end
end
