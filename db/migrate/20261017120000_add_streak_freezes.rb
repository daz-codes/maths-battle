class AddStreakFreezes < ActiveRecord::Migration[8.1]
  def change
    # Freezes held, and the stars spent buying them (a player's stars are what their games earned, less these)
    add_column :users, :streak_freezes, :integer, null: false, default: 0
    add_column :users, :stars_spent, :integer, null: false, default: 0
    # The last day that kept the streak going: practised, or covered by a freeze
    add_column :users, :streak_kept_on, :date

    # Days a freeze covered, so the streak can be worked out again later with them in
    create_table :frozen_days do |t|
      t.references :user, null: false, foreign_key: true
      t.date :day, null: false
      t.timestamps
    end
    add_index :frozen_days, %i[ user_id day ], unique: true

    # Set on the game whose streak earned a freeze, for its results page
    add_column :attempts, :earned_streak_freeze, :boolean, null: false, default: false

    up_only { execute "UPDATE users SET streak_kept_on = last_practised_on" }
  end
end
