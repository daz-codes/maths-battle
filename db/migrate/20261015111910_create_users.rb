class CreateUsers < ActiveRecord::Migration[8.2]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :password_digest, null: false
      t.integer :current_streak, null: false, default: 0
      t.integer :longest_streak, null: false, default: 0
      t.date :last_practised_on
      t.integer :high_score, null: false, default: 0
      t.string :time_zone, null: false, default: "London"

      t.timestamps
    end
    add_index :users, :username, unique: true
  end
end
