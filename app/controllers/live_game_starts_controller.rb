# The host starting their battle, which takes everyone in the lobby to it together
class LiveGameStartsController < ApplicationController
  def create
    live_game = Current.user.hosted_live_games.find_by!(code: params[:live_game_code])
    if live_game.start!
      redirect_to play_path(live: live_game.code)
    else
      redirect_to live_game, alert: "Wait for someone to join first."
    end
  end
end
