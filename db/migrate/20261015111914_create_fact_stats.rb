class CreateFactStats < ActiveRecord::Migration[8.1]
  def change
    create_table :fact_stats do |t|
      t.references :user, null: false, foreign_key: true
      t.string :topic, null: false, default: "times_tables"
      t.string :fact, null: false
      t.integer :correct_count, null: false, default: 0
      t.integer :wrong_count, null: false, default: 0
      t.datetime :last_wrong_at

      t.timestamps
    end
    add_index :fact_stats, %i[user_id topic fact], unique: true
  end
end
