# A game is a level's practice, the daily challenge, or a review of recent mistakes: one mode, not a flag each
class ReplaceDailyChallengeWithMode < ActiveRecord::Migration[8.1]
  def up
    add_column :attempts, :mode, :string, null: false, default: "practice"
    execute "UPDATE attempts SET mode = 'challenge' WHERE daily_challenge"
    remove_index :attempts, %i[ user_id topic daily_challenge played_on ]
    remove_column :attempts, :daily_challenge
    add_index :attempts, %i[ user_id topic mode played_on ]
  end

  def down
    add_column :attempts, :daily_challenge, :boolean, null: false, default: false
    execute "UPDATE attempts SET daily_challenge = (mode = 'challenge')"
    remove_index :attempts, %i[ user_id topic mode played_on ]
    remove_column :attempts, :mode
    add_index :attempts, %i[ user_id topic daily_challenge played_on ]
  end
end
