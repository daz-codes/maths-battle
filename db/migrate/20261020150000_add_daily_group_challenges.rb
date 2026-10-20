# A group challenge can be every day: a round of fresh questions each day, the same for the whole group
class AddDailyGroupChallenges < ActiveRecord::Migration[8.1]
  def change
    add_column :group_challenges, :daily, :boolean, null: false, default: false
    add_column :group_rounds, :day, :date
    add_index :group_rounds, %i[ challenge_id day ], unique: true
  end
end
