# Joining a battle's lobby from its link. A visitor gets a guest account to play with, giving a name if they've
# none, as the others see it
class LiveGamePlayersController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 60, within: 1.minute, with: -> { redirect_to root_path, alert: "Too many tries. Wait a minute, then try again." }

  def create
    live_game = LiveGame.find_by_code(params[:live_game_code])
    return redirect_to(multiplayer_path, alert: "There's no battle with that code.") unless live_game

    player = resume_or_start_guest_session.user
    player.update!(name: params[:name].to_s.strip.first(User::NAME_LENGTH)) if params[:name].present?
    return redirect_to live_game, alert: "Tell us your name first: the other players see it." if player.name.blank? && player.guest?

    notice = "You can't join this game now: it's started or full." unless live_game.join(player)
    redirect_to live_game, alert: notice
  end
end
