# The owner closing a challenge early: its leaderboard stays as it was
class GroupChallengeClosingsController < ApplicationController
  def create
    group = Current.user.owned_groups.find(params[:group_id])
    challenge = group.challenges.find(params[:challenge_id])
    challenge.close!
    redirect_to group_challenge_path(group, challenge), notice: "Challenge closed."
  end
end
