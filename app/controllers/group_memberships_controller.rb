# Leaving a group, or its owner removing someone from it. The owner can't leave their own group: they delete it
class GroupMembershipsController < ApplicationController
  def destroy
    group = Current.user.groups.find(params[:group_id])
    membership = group.memberships.find(params[:id])
    leaving = membership.user == Current.user
    return head :forbidden unless leaving || group.owned_by?(Current.user)
    return redirect_to group, alert: "You own this group: delete it instead." if group.owned_by?(membership.user)

    if leaving
      membership.destroy!
      redirect_to groups_path, notice: "You've left #{group.name}. You can join again with its current invite code."
    else
      group.remove(membership)
      redirect_to group, notice: "#{membership.user.display_name} has been removed. The invite code has changed. Share the new code to invite them back."
    end
  end
end
