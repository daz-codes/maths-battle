class AddLevels < ActiveRecord::Migration[8.1]
  def up
    add_column :attempts, :level, :integer, null: false, default: 1
    # Set when this game unlocked the next level, for its results page
    add_column :attempts, :levelled_up, :boolean, null: false, default: false
    add_column :fact_stats, :level, :integer, null: false, default: 1

    remove_index :fact_stats, %i[ user_id topic fact ]
    add_index :fact_stats, %i[ user_id topic level fact ], unique: true

    # Times tables games so far used tables up to 12: level 2. New players start at level 1, tables 2–5
    execute "UPDATE attempts SET level = 2 WHERE topic = 'times_tables'"
    execute "UPDATE fact_stats SET level = 2 WHERE topic = 'times_tables'"
  end

  def down
    remove_index :fact_stats, %i[ user_id topic level fact ]
    add_index :fact_stats, %i[ user_id topic fact ], unique: true
    remove_column :fact_stats, :level
    remove_column :attempts, :levelled_up
    remove_column :attempts, :level
  end
end
