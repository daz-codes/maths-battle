require "test_helper"
require "open3"
require "tmpdir"

class RewardBackfillsTest < ActiveSupport::TestCase
  test "populated databases upgrade through historical reward migrations without application models" do
    Dir.mktmpdir("matheminute-upgrade-") do |directory|
      output, errors, status = Open3.capture3(RbConfig.ruby, Rails.root.join("test/support/reward_backfill_upgrade.rb").to_s,
        File.join(directory, "upgrade.sqlite3"))
      assert status.success?, "#{output}\n#{errors}"
      result = JSON.parse(output.lines.last)
      assert_equal [ 800, 850, 400 ], result["gems"], "the stars games earned, as gems"
      assert_equal [ "practice" ] * 3, result["modes"]
      badges = result["badges"]
      assert badges.any? { |badge| badge["kind"] == "first_game" && badge["attempt_id"] == result["games"][0] }
      assert badges.any? { |badge| badge["kind"] == "level_2_times_tables" && badge["attempt_id"] == result["games"][0] }
      assert badges.any? { |badge| badge["kind"] == "comeback" && badge["attempt_id"] == result["games"][1] }
      assert badges.any? { |badge| badge["kind"] == "perfect" && badge["user_id"] == result["users"][1] }
      assert_equal badges.map { |badge| badge.values_at("user_id", "kind") }.uniq.size, badges.size
    end
  end
end
