# Joining a group with its code, from a shared link (/join/K7Q2MX) or typed in. A visitor gets a guest account
# to join with, and anyone without a name gives one, as the leaderboard shows it. Rate limited, so codes can't
# be guessed by trying lots of them
class GroupJoinsController < ApplicationController
  allow_unauthenticated_access
  # Both lookups and joins share the limit. A full class can share one school's IP address
  REQUESTS_PER_MINUTE = 120
  rate_limit to: REQUESTS_PER_MINUTE, within: 1.minute, with: -> { redirect_to groups_path, alert: "Too many tries. Wait a minute, then try again." }

  def new
    @group = Group.find_by_code(params[:code])
    return redirect_to groups_path, alert: "There's no group with that code. Check it and try again." unless @group
    return redirect_to @group if @group.member?(Current.user)

    @user = current_player
  end

  def create
    group = Group.find_by_code(params[:code])
    return redirect_to groups_path, alert: "There's no group with that code. Check it and try again." unless group

    player = resume_or_start_guest_session.user
    player.update!(name: params[:name].to_s.strip.first(User::NAME_LENGTH)) if params[:name].present?
    return redirect_to join_group_path(group.join_code), alert: "Tell us your name first: it's shown on the leaderboard." if player.name.blank? && player.guest?

    group.join(player, code: params[:code])
    redirect_to group, notice: "You've joined #{group.name}!"
  rescue Group::Full
    redirect_to groups_path, alert: "That group is full."
  rescue Group::InvalidCode
    redirect_to groups_path, alert: "That invite code has changed. Ask the group's owner for a new invitation."
  end
end
