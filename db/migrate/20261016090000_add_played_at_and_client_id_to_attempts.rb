class AddPlayedAtAndClientIdToAttempts < ActiveRecord::Migration[8.1]
  def up
    # When the game was played, which can be before it reaches the server if it was played offline
    add_column :attempts, :played_at, :datetime
    # The day it counts towards, in the player's time zone
    add_column :attempts, :played_on, :date
    # Made on the device, so a game uploaded twice is only counted once
    add_column :attempts, :client_id, :string
    add_index :attempts, %i[ user_id client_id ], unique: true
    add_index :attempts, %i[ user_id played_on ]

    backfill_play_times
  end

  def down
    remove_index :attempts, %i[ user_id played_on ]
    remove_index :attempts, %i[ user_id client_id ]
    remove_column :attempts, :client_id
    remove_column :attempts, :played_on
    remove_column :attempts, :played_at
  end

  private
    # Games so far were saved as they were played
    def backfill_play_times
      select_rows("SELECT attempts.id, attempts.created_at, users.time_zone FROM attempts JOIN users ON users.id = attempts.user_id").each do |id, created_at, time_zone|
        played_at = ActiveSupport::TimeZone["UTC"].parse(created_at.to_s) # SQLite stores times in UTC
        execute sanitize_sql([ "UPDATE attempts SET played_at = ?, played_on = ? WHERE id = ?", played_at, played_at.in_time_zone(time_zone).to_date, id ])
      end
    end

    def sanitize_sql(statement)
      ActiveRecord::Base.sanitize_sql_array(statement)
    end
end
