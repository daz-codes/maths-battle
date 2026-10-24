# The level picker on the practice page, for the current topic
class LevelsController < ApplicationController
  allow_unauthenticated_access

  def update
    level = level_from_params(current_topic)
    remember_level(current_topic, level) if level
    redirect_to practice_path
  end
end
