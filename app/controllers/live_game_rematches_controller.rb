# The host playing again with everyone from their last battle: its next lobby (LiveGame::Rematchable)
class LiveGameRematchesController < ApplicationController
  rate_limit to: 10, within: 10.minutes

  def create
    live_game = Current.user.hosted_live_games.find_by!(code: params[:live_game_code])
    if (rematch = live_game.play_again!)
      redirect_to rematch
    else
      redirect_to live_game, alert: "Start this game first."
    end
  end
end
