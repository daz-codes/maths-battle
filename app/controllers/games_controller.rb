class GamesController < ApplicationController
  allow_unauthenticated_access

  # A level's game, or, in a topic that plays by medals, its practice (that level's questions only) or the
  # daily challenge (?challenge=1: every level up to the player's, once a day)
  def show
    @topic = topic_from_slug
    @daily_challenge = @topic.medals? && params[:challenge].present?
    return redirect_to(root_path, notice: "You've done today's daily challenge. Come back tomorrow!") if @daily_challenge && current_player.daily_challenge_on(@topic)

    @level = @daily_challenge ? current_player.unlocked_level(@topic) : level_from_params(@topic) || current_level(@topic)
    remember_topic @topic
    @question_sets = current_player.question_sets(topic: @topic, level: @level, mix: question_mix)
    @question_sets.each do |set|
      set[:ticket] = Attempt::GameTicket.issue(owner: player_key, topic: @topic.key, level: @level, daily_challenge: @daily_challenge, **set.slice(:id, :questions))
    end
  end

  private
    def question_mix
      if @daily_challenge then :all_levels
      elsif @topic.medals? then :level_only
      else :review
      end
    end
end
