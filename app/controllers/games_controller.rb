class GamesController < ApplicationController
  allow_unauthenticated_access

  # A level's practice (that level's questions only), the daily challenge (?challenge=1: every level up to the
  # player's, once a day), or a review (?review=1: their recent mistakes, asked again)
  def show
    @topic = topic_from_slug
    @mode = params[:challenge].present? ? "challenge" : params[:review].present? ? "review" : "practice"
    return redirect_to(root_path, notice: "You've done today's daily challenge. Come back tomorrow!") if @mode == "challenge" && current_player.daily_challenge_on(@topic)
    return redirect_to(root_path, notice: "Nothing to review yet. Play some games first!") if @mode == "review" && current_player.review_questions(@topic).empty?

    @level = @mode == "practice" ? level_from_params(@topic) || current_level(@topic) : current_player.unlocked_level(@topic)
    remember_topic @topic
    @question_sets = question_sets
    @question_sets.each do |set|
      set[:ticket] = Attempt::GameTicket.issue(owner: player_key, topic: @topic.key, level: @level, mode: @mode, **set.slice(:id, :questions))
    end
  end

  private
    def question_sets
      case @mode
      when "review" then current_player.review_sets(topic: @topic)
      else current_player.question_sets(topic: @topic, level: @level, mix: @mode == "challenge" ? :all_levels : :level_only)
      end
    end
end
