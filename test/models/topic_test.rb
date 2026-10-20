require "test_helper"

class TopicTest < ActiveSupport::TestCase
  test "every topic answers the same questions about itself" do
    assert_equal [ "times_tables", "times-tables", "Times tables", "✖️" ], [ TimesTables.key, TimesTables.slug, TimesTables.title, TimesTables.emoji ]
    assert_equal [ "equations", "equations", "Equations", "⚖️" ], [ Equations.key, Equations.slug, Equations.title, Equations.emoji ]
    assert_equal [ "functions", "functions", "Functions", "⚙️" ], [ Functions.key, Functions.slug, Functions.title, Functions.emoji ]
    assert_equal [ "fractions", "fractions", "Fractions", "🍕" ], [ Fractions.key, Fractions.slug, Fractions.title, Fractions.emoji ]
    assert_equal [ "addition", "adding-and-subtracting", "Adding and subtracting", "➕" ], [ Addition.key, Addition.slug, Addition.title, Addition.emoji ]
    assert_equal [ "percentages", "percentages", "Percentages", "💯" ], [ Percentages.key, Percentages.slug, Percentages.title, Percentages.emoji ]
    assert_equal [ "division", "division", "Division", "➗" ], [ Division.key, Division.slug, Division.title, Division.emoji ]
    assert_equal [ "negatives", "negative-numbers", "Negative numbers", "🌡️" ], [ Negatives.key, Negatives.slug, Negatives.title, Negatives.emoji ]
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
    assert_equal %w[ addition times_tables division negatives fractions percentages equations functions simultaneous ], Topic.keys
  end

  test "a topic keeps its own module name" do
    assert_equal "TimesTables", TimesTables.name
  end
end
