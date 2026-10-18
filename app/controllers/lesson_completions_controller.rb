# Finishing a lesson, sent by the lesson page. A visitor who hasn't played yet gets a guest account, as with a
# first game, so the streak has somewhere to go
class LessonCompletionsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 20, within: 1.minute

  def create
    topic = topic_from_slug
    level = level_from_params(topic)
    return head(:unprocessable_entity) unless level && topic.lesson(level)

    player = resume_or_start_guest_session.user
    player.update_time_zone(params[:time_zone])
    render json: { streak: player.complete_lesson!(topic, level) }
  end
end
