# Which topic the player is on. Remembered on the device, and changed by the topic switcher or by playing one
module Topical
  extend ActiveSupport::Concern

  included do
    helper_method :current_topic
  end

  private
    def current_topic
      Topic.find(cookies[:topic]) || Topic.default
    end

    def remember_topic(topic)
      cookies.permanent[:topic] = topic::TOPIC
    end

    def topic_from_slug
      Topic.find_by_slug(params[:topic]) || raise(ActionController::RoutingError, "No such topic")
    end
end
