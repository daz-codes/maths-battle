# Changing topic, on a page of its own like changing language in Duolingo: every topic with the player's
# progress in it. Picking one makes it the current topic, back on the page the player came from
class TopicsController < ApplicationController
  allow_unauthenticated_access

  def index
    @user = current_player
  end

  def update
    remember_topic topic_from_slug
    redirect_to back_path
  end

  private
    def back_path
      case params[:from]
      when "stats" then stats_path
      when "practice" then practice_path
      when "profile" then edit_profile_path
      else root_path
      end
    end
end
