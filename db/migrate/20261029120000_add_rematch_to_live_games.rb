# Playing again: a finished live game points to the next one its host made for the same players (LiveGame::Rematchable)
class AddRematchToLiveGames < ActiveRecord::Migration[8.1]
  def change
    add_reference :live_games, :rematch, foreign_key: { to_table: :live_games, on_delete: :nullify }
  end
end
