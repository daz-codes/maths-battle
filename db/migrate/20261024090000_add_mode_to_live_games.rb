# A live game is Classic (most right answers wins) or Power (most gems wins). A new column on live_games only
class AddModeToLiveGames < ActiveRecord::Migration[8.1]
  def change
    add_column :live_games, :mode, :string, default: "classic", null: false
  end
end
