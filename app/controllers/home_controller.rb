class HomeController < ApplicationController
  allow_unauthenticated_access

  def show
    @user = current_player
  end
end
