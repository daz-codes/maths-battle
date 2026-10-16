# The topic switcher on the home page
class TopicsController < ApplicationController
  allow_unauthenticated_access

  def update
    remember_topic topic_from_slug
    redirect_to root_path
  end
end
