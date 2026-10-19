class HomeController < ApplicationController
  allow_unauthenticated_access

  # A new player picks a topic first
  def show
    return redirect_to topics_path unless topic_chosen?

    @user = current_player
  end
end
