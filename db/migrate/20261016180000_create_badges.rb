class CreateBadges < ActiveRecord::Migration[8.1]
  def change
    create_table :badges do |t|
      t.references :user, null: false, foreign_key: true
      # The game that earned it, for its results page
      t.references :attempt, foreign_key: { on_delete: :nullify }
      t.string :kind, null: false
      # When that game was played, which for an offline game is before it reached the server
      t.datetime :earned_at, null: false
      t.timestamps
    end
    add_index :badges, %i[ user_id kind ], unique: true
  end
end
