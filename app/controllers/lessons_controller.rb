# A level's tutorial: a worked example to tap through, then one to try. Only for levels the player has unlocked
class LessonsController < ApplicationController
  allow_unauthenticated_access

  def show
    @topic = topic_from_slug
    @level = level_from_params(@topic)
    return redirect_to(root_path, alert: "Unlock that level first.") unless @level

    @lesson = @topic.lesson(@level) || raise(ActionController::RoutingError, "No lesson")
  end
end
