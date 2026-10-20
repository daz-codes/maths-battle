# Replacing an invitation: only the owner can do it, and existing players stay in the group
class GroupInviteCodesController < ApplicationController
  def create
    group = Current.user.owned_groups.find(params[:group_id])
    group.renew_join_code!
    redirect_to group, notice: "New invite code ready. Old codes and links no longer work. Existing players stay joined."
  end
end
