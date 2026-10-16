require "test_helper"

class BadgeTest < ActiveSupport::TestCase
  test "every badge has its own key, a group, and a rule a game can answer" do
    assert_equal Badge.keys.uniq, Badge.keys
    Badge.catalogue.each do |kind|
      assert_includes Badge::GROUPS.keys, kind.group, kind.key
      assert_respond_to Attempt.new, kind.check.first, kind.key
    end
  end

  test "there are score and level badges for each topic" do
    assert Badge.kind("score_100_times_tables")
    assert Badge.kind("score_50_equations")
    assert Badge.kind("level_5_equations")
    assert_nil Badge.kind("level_1_times_tables"), "everyone starts at level 1"
  end

  test "only badges in the catalogue can be saved" do
    assert_not users(:ada).badges.new(kind: "made_up", earned_at: Time.current).valid?
  end
end
