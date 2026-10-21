# What games earn is gems now; stars rate how well a level's been done. SQLite renames the columns in place: Rails'
# rename_column rebuilds the table, which for attempts would clear every badge's link to the game that earned it
class RenameStarsToGems < ActiveRecord::Migration[8.1]
  def up
    execute "ALTER TABLE attempts RENAME COLUMN stars TO gems"
    execute "ALTER TABLE users RENAME COLUMN stars_spent TO gems_spent"
  end

  def down
    execute "ALTER TABLE attempts RENAME COLUMN gems TO stars"
    execute "ALTER TABLE users RENAME COLUMN gems_spent TO stars_spent"
  end
end
