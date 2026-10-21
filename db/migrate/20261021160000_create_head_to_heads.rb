# Two players on the same questions (HeadToHead). A new table: attempts isn't touched, as rebuilding it in SQLite
# would empty badges.attempt_id
class CreateHeadToHeads < ActiveRecord::Migration[8.1]
  def change
    create_table :head_to_heads do |t|
      t.references :challenger, null: false, foreign_key: { to_table: :users }
      t.references :opponent, null: false, foreign_key: { to_table: :users }
      t.string :topic, null: false
      t.integer :level, null: false
      t.boolean :mixed, default: false, null: false
      t.json :questions, null: false
      t.references :challenger_attempt, foreign_key: { to_table: :attempts, on_delete: :nullify }
      t.references :opponent_attempt, foreign_key: { to_table: :attempts, on_delete: :nullify }
      t.datetime :expires_at
      t.datetime :decided_at
      t.references :winner, foreign_key: { to_table: :users }
      t.timestamps
    end
  end
end
