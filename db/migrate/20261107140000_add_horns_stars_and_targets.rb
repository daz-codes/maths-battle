# A battle's Horns held and Superstars running (LiveGame::Droppable), and for each drop who a Homing shot went for
# and whom a Horn or a Superstar saved
class AddHornsStarsAndTargets < ActiveRecord::Migration[8.1]
  def change
    add_column :live_game_players, :horns, :integer, null: false, default: 0
    add_column :live_game_players, :star_until, :datetime
    add_reference :live_game_drops, :target, foreign_key: { to_table: :users }
    add_column :live_game_drops, :blocked_ids, :json, null: false, default: []
  end
end
