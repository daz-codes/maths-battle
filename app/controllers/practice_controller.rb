# Practice: the current topic's levels to play over and over, mixed practice, and reviewing mistakes
class PracticeController < ApplicationController
  allow_unauthenticated_access

  # A new player picks a topic first
  def show
    return redirect_to topics_path unless topic_chosen?

    @user = current_player
  end
end
