# A game is a level's practice, the daily challenge, or a review of recent mistakes: one mode, not a flag each
class ReplaceDailyChallengeWithMode < ActiveRecord::Migration[8.1]
  def up
    add_column :attempts, :mode, :string, null: false, default: "practice"
    execute "UPDATE attempts SET mode = 'challenge' WHERE daily_challenge"
    remove_index :attempts, %i[ user_id topic daily_challenge played_on ]
    remove_attempt_column :daily_challenge
    add_index :attempts, %i[ user_id topic mode played_on ]
  end

  def down
    add_column :attempts, :daily_challenge, :boolean, null: false, default: false
    execute "UPDATE attempts SET daily_challenge = (mode = 'challenge')"
    remove_index :attempts, %i[ user_id topic mode played_on ]
    remove_attempt_column :mode
    add_index :attempts, %i[ user_id topic daily_challenge played_on ]
  end

  private
    # SQLite rebuilds attempts when dropping a column. Its ON DELETE SET NULL foreign key can detach
    # badges during that rebuild, so preserve their links in both migration directions.
    def remove_attempt_column(column)
      badges = select_rows("SELECT id, attempt_id FROM badges WHERE attempt_id IS NOT NULL")
      remove_column :attempts, column
      badges.each do |id, attempt_id|
        execute "UPDATE badges SET attempt_id = #{connection.quote(attempt_id)} WHERE id = #{connection.quote(id)}"
      end
    end
end
