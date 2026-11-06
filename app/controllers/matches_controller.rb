# Finding a match: the page waits, open, until there's someone to battle (MatchmakingChannel). Its player needs a
# session for the channel to know them, and a name, as the others see it, so a visitor gives one first
class MatchesController < ApplicationController
  allow_unauthenticated_access

  def show
    @user = current_player
    @waiting = MatchRequest.waiting_count
  end

  def create
    player = resume_or_start_guest_session.user
    player.update!(name: params[:name].to_s.strip.first(User::NAME_LENGTH)) if params[:name].present?
    return redirect_to match_path, alert: "Tell us your name first: the other players see it." unless player.named?

    redirect_to match_path(looking: 1)
  end
end
