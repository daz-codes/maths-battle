class AddBestScoreToAttempts < ActiveRecord::Migration[8.1]
  def up
    # The best score in the topic and level when the game was played, for its results and share pages
    add_column :attempts, :best_score, :integer, null: false, default: 0

    execute <<~SQL
      UPDATE attempts SET best_score = (
        SELECT MAX(earlier.score) FROM attempts earlier
        WHERE earlier.user_id = attempts.user_id AND earlier.topic = attempts.topic AND earlier.level = attempts.level
          AND earlier.created_at <= attempts.created_at
      )
    SQL
  end

  def down
    remove_column :attempts, :best_score
  end
end
