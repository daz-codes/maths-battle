# Live games: the host makes one at their topic and level, and its page is the lobby (who's in, the link to
# share, and for the host the choice of Classic or Power and the Start button), then the game under way, then
# the podium
class LiveGamesController < ApplicationController
  allow_unauthenticated_access only: :show
  rate_limit to: 10, within: 10.minutes, only: :create

  def create
    live_game = LiveGame.make(host: Current.user, topic: current_topic, level: current_level)
    redirect_to live_game
  end

  # Classic or Power, before it starts
  def update
    live_game = Current.user.hosted_live_games.find_by!(code: params[:code])
    live_game.choose_mode(params[:mode].to_s)
    redirect_to live_game
  end

  def show
    @live_game = LiveGame.includes(:host).find_by_code(params[:code])
    return redirect_to(groups_path, alert: "There's no live game with that code. Check it and try again.") unless @live_game

    @user = current_player
    @player = @live_game.player_for(@user) if @user.persisted?
  end
end
