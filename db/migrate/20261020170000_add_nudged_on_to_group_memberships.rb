# The last day a player was told someone took 1st place from them in a group, so it's at most once a day
class AddNudgedOnToGroupMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :group_memberships, :nudged_on, :date
  end
end
