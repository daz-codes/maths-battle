class StatsController < ApplicationController
  allow_unauthenticated_access

  def show
    @user = current_player
    @topic = params[:topic] ? topic_from_slug : current_topic
  end
end
