class AddStarsToAttempts < ActiveRecord::Migration[8.1]
  def change
    # What the game earned, so a player's total is the sum of their games
    add_column :attempts, :stars, :integer, null: false, default: 0
  end
end
