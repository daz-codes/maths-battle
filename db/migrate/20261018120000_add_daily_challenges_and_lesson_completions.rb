class AddDailyChallengesAndLessonCompletions < ActiveRecord::Migration[8.1]
  def change
    # A daily challenge mixes every level up to the player's, so it belongs to no level: its own scores and best
    add_column :attempts, :daily_challenge, :boolean, null: false, default: false
    add_index :attempts, %i[ user_id topic daily_challenge played_on ]

    # Finishing a lesson keeps the streak going for that day, like a game
    create_table :lesson_completions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :topic, null: false
      t.integer :level, null: false
      t.date :completed_on, null: false
      t.timestamps
    end
    add_index :lesson_completions, %i[ user_id topic level completed_on ], unique: true
  end
end
