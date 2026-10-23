# Live games (LiveGame): a host, a lobby of players and one set of questions everyone plays at the same time.
# New tables only: attempts isn't touched, as rebuilding it in SQLite would empty badges.attempt_id
class CreateLiveGames < ActiveRecord::Migration[8.1]
  def change
    create_table :live_games do |t|
      t.references :host, null: false, foreign_key: { to_table: :users }
      t.string :code, null: false, index: { unique: true }
      t.string :topic, null: false
      t.integer :level, null: false
      t.boolean :mixed, default: false, null: false
      t.json :questions, null: false
      t.datetime :starts_at
      t.timestamps
    end

    create_table :live_game_players do |t|
      t.references :live_game, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :attempt, foreign_key: { on_delete: :nullify }
      t.timestamps
      t.index %i[ live_game_id user_id ], unique: true
    end
  end
end
