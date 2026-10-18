# Changing topic, on a page of its own like changing language in Duolingo: every topic with the player's
# progress in it. Picking one makes it the current topic, back on the page the player came from
class TopicsController < ApplicationController
  allow_unauthenticated_access

  def index
    @user = current_player
  end

  def update
    remember_topic topic_from_slug
    redirect_to params[:from] == "stats" ? stats_path : root_path
  end
end
