# Which topic the player is on, and which of its levels. Remembered on the device, and changed by the switchers
# or by playing. Play defaults to the highest unlocked level; picking an easier one is remembered until they level up
module Topical
  extend ActiveSupport::Concern

  included do
    helper_method :current_topic, :current_level
  end

  private
    def current_topic
      Topic.find(cookies[:topic]) || Topic.default
    end

    def remember_topic(topic)
      cookies.permanent[:topic] = topic.key
    end

    def topic_from_slug
      Topic.find_by_slug(params[:topic]) || raise(ActionController::RoutingError, "No such topic")
    end

    def current_level(topic = current_topic)
      unlocked = current_player.unlocked_level(topic)
      chosen = cookies[level_cookie(topic)].to_i
      chosen.between?(1, unlocked) ? chosen : unlocked
    end

    def remember_level(topic, level)
      cookies.permanent[level_cookie(topic)] = level
    end

    # After levelling up, Play goes to the new level
    def forget_level(topic)
      cookies.delete(level_cookie(topic))
    end

    # A level from the request, if it's one they've unlocked
    def level_from_params(topic)
      level = params[:level].to_i
      level if level.between?(1, current_player.unlocked_level(topic))
    end

    def level_cookie(topic)
      "level_#{topic.key}"
    end
end
