# Multiplayer's choices: find a match with anyone looking, host a battle for friends, or join one with its code
class MultiplayerController < ApplicationController
  allow_unauthenticated_access

  def show
    @user = current_player
  end
end
