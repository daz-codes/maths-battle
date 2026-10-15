class CreateAttempts < ActiveRecord::Migration[8.2]
  def change
    create_table :attempts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :topic, null: false, default: "times_tables"
      t.integer :score, null: false, default: 0
      t.integer :answered, null: false, default: 0
      t.json :results, null: false, default: []
      t.boolean :new_high_score, null: false, default: false
      t.integer :streak, null: false, default: 0
      t.string :share_token, null: false

      t.timestamps
    end
    add_index :attempts, :share_token, unique: true
    add_index :attempts, %i[user_id created_at]
  end
end
