# Awards: what a player has earned, once each, and the game that earned it (none for joining a league)
class CreateBadges < ActiveRecord::Migration[8.1]
  def change
    create_table :badges do |t|
      t.references :user, null: false, foreign_key: true
      t.references :attempt, foreign_key: { on_delete: :nullify }
      t.string :kind, null: false
      t.datetime :earned_at, null: false
      t.timestamps
      t.index %i[ user_id kind ], unique: true
    end
  end
end
