# Every badge, with the ones the player has earned picked out
class BadgesController < ApplicationController
  allow_unauthenticated_access

  def show
    @user = current_player
  end
end
