class GamesController < ApplicationController
  allow_unauthenticated_access

  # A level's practice (that level's questions only), the daily challenge (?challenge=1: every level up to the
  # player's, once a day), a review (?review=1: their recent mistakes, asked again), or a group challenge
  # (?round=: its one set of questions, at the level its owner set)
  def show
    @topic = topic_from_slug
    @mode = params[:round].present? ? "group" : params[:challenge].present? ? "challenge" : params[:review].present? ? "review" : "practice"
    return redirect_to(root_path, notice: "You've done today's daily challenge. Come back tomorrow!") if @mode == "challenge" && current_player.daily_challenge_on(@topic)
    return redirect_to(root_path, notice: "Nothing to review yet. Play some games first!") if @mode == "review" && current_player.review_questions(@topic).empty?
    return redirect_to(groups_path, notice: "That group challenge has finished.") if @mode == "group" && !group_round

    @level = game_level
    remember_topic @topic unless @mode == "group"
    @question_sets = question_sets
    @question_sets.each do |set|
      set[:ticket] = Attempt::GameTicket.issue(owner: player_key, topic: @topic.key, level: @level, mode: @mode, round: @round, **set.slice(:id, :questions))
    end
  end

  private
    def game_level
      case @mode
      when "practice" then level_from_params(@topic) || current_level(@topic)
      when "group" then @round.challenge.level
      else current_player.unlocked_level(@topic)
      end
    end

    # The round of an open challenge in this topic, if the player is one of its players. For an every day
    # challenge, only today's
    def group_round
      @round = Group::Round.find_by(id: params[:round])
      @round = nil unless @round && @round.challenge.topic_module == @topic && @round.challenge.playable_by?(current_player) && @round.current?
      @round
    end

    def question_sets
      case @mode
      when "review" then current_player.review_sets(topic: @topic)
      when "group" then [ { id: SecureRandom.hex(16), questions: @round.questions } ]
      else current_player.question_sets(topic: @topic, level: @level, mix: @mode == "challenge" ? :all_levels : :level_only)
      end
    end
end
