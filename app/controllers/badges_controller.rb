# Every badge, with the ones the player has earned picked out. Players know this page as their achievements
class BadgesController < ApplicationController
  allow_unauthenticated_access

  def show
    @user = current_player
  end
end
