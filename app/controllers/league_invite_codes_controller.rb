# Replacing an invitation: only the owner can do it, and existing players stay in the league
class LeagueInviteCodesController < ApplicationController
  def create
    league = Current.user.owned_leagues.find(params[:league_id])
    league.renew_join_code!
    redirect_to league, notice: "New invite code ready. Old codes and links no longer work. Existing players stay in."
  end
end
