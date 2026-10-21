class GamesController < ApplicationController
  allow_unauthenticated_access

  # A level's practice (that level's questions only), mixed practice (?mixed=1: every level up to the player's),
  # a review (?review=1: their recent mistakes, asked again), or a group challenge (?round=: its one set of
  # questions). There's no daily challenge any more: a link to one, from a page kept offline, is mixed practice
  def show
    @topic = topic_from_slug
    return redirect_to(play_path(@topic.slug, mixed: 1)) if params[:challenge].present?

    @mode = game_mode
    return redirect_to(root_path, notice: "Nothing to review yet. Play some games first!") if @mode == "review" && current_player.review_questions(@topic).empty?
    return redirect_to(groups_path, notice: "That group challenge has finished.") if @mode == "group" && !group_round

    @level = game_level
    @best = @mode == "practice" ? current_player.best_score(@topic, @level) : 0
    remember_topic @topic unless @mode == "group"
    @question_sets = question_sets
    @question_sets.each do |set|
      set[:ticket] = Attempt::GameTicket.issue(owner: player_key, topic: @topic.key, level: @level, mode: @mode, round: @round, **set.slice(:id, :questions))
    end
  end

  private
    def game_mode
      if params[:round].present? then "group"
      elsif params[:mixed].present? then "mixed"
      elsif params[:review].present? then "review"
      else "practice"
      end
    end

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
      else current_player.question_sets(topic: @topic, level: @level, mix: @mode == "mixed" ? :all_levels : :level_only)
      end
    end
end
