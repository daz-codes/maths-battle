require_relative "support/legacy_game_backfill"

# Existing players get the stars their games so far have earned.
class AwardStarsForGamesAlreadyPlayed < ActiveRecord::Migration[8.1]
  def up
    LegacyGameBackfill.new(connection).stars
  end

  def down
    execute "UPDATE attempts SET stars = 0"
  end
end
