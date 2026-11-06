# Leaving a league, or its owner removing someone from it. The owner can't leave their own league: they delete it
class LeagueMembershipsController < ApplicationController
  def destroy
    league = Current.user.leagues.find(params[:league_id])
    membership = league.memberships.find(params[:id])
    leaving = membership.user == Current.user
    return head :forbidden unless leaving || league.owned_by?(Current.user)
    return redirect_to league, alert: "You own this league: delete it instead." if league.owned_by?(membership.user)

    if leaving
      membership.destroy!
      redirect_to leagues_path, notice: "You've left #{league.name}. You can join again with its current invite code."
    else
      league.remove(membership)
      redirect_to league, notice: "#{membership.user.display_name} has been removed. The invite code has changed. Share the new code to invite them back."
    end
  end
end
