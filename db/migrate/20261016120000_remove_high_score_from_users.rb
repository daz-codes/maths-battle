class RemoveHighScoreFromUsers < ActiveRecord::Migration[8.1]
  # Best scores are per topic now, worked out from each topic's games
  def change
    remove_column :users, :high_score, :integer, null: false, default: 0
  end
end
