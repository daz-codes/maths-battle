require_relative "support/points_backfill"

# A game's score is now its points (right answers, their speed and runs of them, less wrong ones), as gems were, and
# what was its score is how many it got right. Columns are renamed and added in place, never rebuilding attempts,
# which would empty badges.attempt_id. A live game player's gems so far are their score so far
class ScoreGamesByPoints < ActiveRecord::Migration[8.1]
  def up
    execute "ALTER TABLE attempts RENAME COLUMN score TO correct"
    execute "ALTER TABLE attempts RENAME COLUMN best_score TO best_correct"
    add_column :attempts, :score, :integer, default: 0, null: false
    add_column :attempts, :best_score, :integer, default: 0, null: false
    execute "ALTER TABLE live_game_players RENAME COLUMN live_gems TO live_score" if table_exists?(:live_game_players)
    PointsBackfill.new(connection).run
  end

  def down
    execute "ALTER TABLE live_game_players RENAME COLUMN live_score TO live_gems" if table_exists?(:live_game_players)
    execute "ALTER TABLE attempts DROP COLUMN best_score"
    execute "ALTER TABLE attempts DROP COLUMN score"
    execute "ALTER TABLE attempts RENAME COLUMN best_correct TO best_score"
    execute "ALTER TABLE attempts RENAME COLUMN correct TO score"
  end
end
