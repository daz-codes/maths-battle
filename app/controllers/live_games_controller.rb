# Hosted battles: the host makes one, and its page is the lobby (who's in, the code to share, and for the host the
# Start button), then the battle under way, then the podium
class LiveGamesController < ApplicationController
  allow_unauthenticated_access only: %i[ index show ]
  rate_limit to: 10, within: 10.minutes, only: :create

  def create
    redirect_to LiveGame.host!(Current.user)
  end

  # A code typed in, spaces and case as they come
  def index
    redirect_to live_game_path(params[:code].to_s.upcase.delete("^A-Z0-9").presence || "-")
  end

  def show
    @live_game = LiveGame.includes(:host).find_by_code(params[:code])
    return redirect_to(multiplayer_path, alert: "There's no battle with that code. Check it and try again.") unless @live_game

    @user = current_player
    @player = @live_game.player_for(@user) if @user.persisted?
  end
end
