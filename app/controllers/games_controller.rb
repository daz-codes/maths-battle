class GamesController < ApplicationController
  allow_unauthenticated_access

  def show
    @topic = topic_from_slug
    @level = level_from_params(@topic) || current_level(@topic)
    remember_topic @topic
    @question_sets = current_player.question_sets(topic: @topic, level: @level)
    @question_sets.each do |set|
      set[:ticket] = Attempt::GameTicket.issue(owner: player_key, topic: @topic.key, level: @level, **set.slice(:id, :questions))
    end
  end
end
