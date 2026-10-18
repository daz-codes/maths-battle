class GamesController < ApplicationController
  allow_unauthenticated_access

  # A level's practice (that level's questions only), or the daily challenge (?challenge=1: every level up to
  # the player's, once a day)
  def show
    @topic = topic_from_slug
    @daily_challenge = params[:challenge].present?
    return redirect_to(root_path, notice: "You've done today's daily challenge. Come back tomorrow!") if @daily_challenge && current_player.daily_challenge_on(@topic)

    @level = @daily_challenge ? current_player.unlocked_level(@topic) : level_from_params(@topic) || current_level(@topic)
    remember_topic @topic
    @question_sets = current_player.question_sets(topic: @topic, level: @level, mix: @daily_challenge ? :all_levels : :level_only)
    @question_sets.each do |set|
      set[:ticket] = Attempt::GameTicket.issue(owner: player_key, topic: @topic.key, level: @level, daily_challenge: @daily_challenge, **set.slice(:id, :questions))
    end
  end
end
