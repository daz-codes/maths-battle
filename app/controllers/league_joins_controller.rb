# Joining a league with its code, from a shared link (/join/K7Q2MX) or typed in. A visitor gets a guest account to
# join with, and anyone without a name gives one, as the table shows it. Rate limited, so codes can't be guessed by
# trying lots of them
class LeagueJoinsController < ApplicationController
  allow_unauthenticated_access
  # Both lookups and joins share the limit. A whole class can share one school's IP address
  REQUESTS_PER_MINUTE = 120
  rate_limit to: REQUESTS_PER_MINUTE, within: 1.minute, with: -> { redirect_to leagues_path, alert: "Too many tries. Wait a minute, then try again." }

  def new
    @league = League.find_by_code(params[:code])
    return redirect_to leagues_path, alert: "There's no league with that code. Check it and try again." unless @league
    return redirect_to @league if @league.member?(Current.user)

    @user = current_player
  end

  def create
    league = League.find_by_code(params[:code])
    return redirect_to leagues_path, alert: "There's no league with that code. Check it and try again." unless league

    player = resume_or_start_guest_session.user
    player.update!(name: params[:name].to_s.strip.first(User::NAME_LENGTH)) if params[:name].present?
    return redirect_to join_league_path(league.join_code), alert: "Tell us your name first: it's shown in the league." unless player.named?

    league.join(player, code: params[:code])
    redirect_to league, notice: "You've joined #{league.name}!"
  rescue League::Full
    redirect_to leagues_path, alert: "That league is full."
  rescue League::InvalidCode
    redirect_to leagues_path, alert: "That invite code has changed. Ask the league's owner for a new invitation."
  end
end
