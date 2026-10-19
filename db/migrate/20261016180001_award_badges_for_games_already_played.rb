require_relative "support/legacy_game_backfill"

# Existing players get the badges their games so far have earned.
class AwardBadgesForGamesAlreadyPlayed < ActiveRecord::Migration[8.1]
  def up
    LegacyGameBackfill.new(connection).badges(perfect_answers: 20)
  end

  def down
    execute "DELETE FROM badges"
  end
end
