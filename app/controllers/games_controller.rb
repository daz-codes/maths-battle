class GamesController < ApplicationController
  allow_unauthenticated_access

  def show
    @topic = topic_from_slug
    remember_topic @topic
    @question_sets = current_player.question_sets(topic: @topic)
  end
end
