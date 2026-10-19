# Sounds and vibration in games, on unless the player turns them off
class AddSoundsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :sounds, :boolean, default: true, null: false
  end
end
