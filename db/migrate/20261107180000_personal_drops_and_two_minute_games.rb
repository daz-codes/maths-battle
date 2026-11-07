# Games last two minutes now, so every game, award and battle from one-minute games is wiped, to start again on the
# same footing; accounts and leagues stay. And a battle's power-ups are each player's own (owner), with an extra
# one for a player who falls far behind (caught_up_at, the last time they had one)
class PersonalDropsAndTwoMinuteGames < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM badges"
    execute "DELETE FROM live_game_drops"
    execute "DELETE FROM live_game_players"
    execute "UPDATE live_games SET rematch_id = NULL"
    execute "DELETE FROM live_games"
    execute "DELETE FROM match_requests"
    execute "DELETE FROM attempts"

    add_reference :live_game_drops, :owner, foreign_key: { to_table: :users }
    add_column :live_game_players, :caught_up_at, :datetime
  end

  def down
    remove_column :live_game_players, :caught_up_at
    remove_reference :live_game_drops, :owner
  end
end
