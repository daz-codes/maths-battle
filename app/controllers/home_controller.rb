# Single player or multiplayer, and where they are in today's world league
class HomeController < ApplicationController
  allow_unauthenticated_access

  def show
    @user = current_player
    @world = League.world
    @standing = @world.entry_for(@user)
  end
end
