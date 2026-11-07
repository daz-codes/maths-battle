# Every award, with the ones the player has earned picked out
class AwardsController < ApplicationController
  allow_unauthenticated_access

  def show
    @user = current_player
  end
end
