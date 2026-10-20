# A group challenge can be mixed: questions from every level of its topic, like the daily challenge
class AddMixedToGroupChallenges < ActiveRecord::Migration[8.1]
  def change
    add_column :group_challenges, :mixed, :boolean, null: false, default: false
  end
end
