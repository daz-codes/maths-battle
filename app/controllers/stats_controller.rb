class StatsController < ApplicationController
  allow_unauthenticated_access

  def show
    @user = current_player
    @topic = params[:topic] ? topic_from_slug : current_topic
    @level = level_from_params(@topic) || current_level(@topic)
  end
end
