# Power-ups in a Power live game (LiveGame::Powerable): each player's gems as they last said, to know who's ahead,
# how many boxes they've had, and what they're holding. New columns on live_game_players only
class AddPowerUpsToLiveGamePlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :live_game_players, :live_gems, :integer, default: 0, null: false
    add_column :live_game_players, :boxes_opened, :integer, default: 0, null: false
    add_column :live_game_players, :power_up, :string
  end
end
