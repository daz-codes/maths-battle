class GamesController < ApplicationController
  allow_unauthenticated_access

  # A level's practice (that level's questions only), mixed practice (?mixed=1: every level up to the player's),
  # a review (?review=1: their recent mistakes, asked again), a group challenge (?round=: its one set of
  # questions), a head to head (?head_to_head=: its set, with the challenger's score to beat), or a live game
  # (?live=: its set, starting when everyone's does), or a daily challenge (?daily=tables or patternz: today's set,
  # once a day). There's no daily challenge any more: a link to one, from a page kept offline, is mixed practice
  def show
    @topic = topic_from_slug
    return redirect_to(play_path(@topic.slug, mixed: 1)) if params[:challenge].present?

    @mode = game_mode
    return redirect_to(root_path, notice: "Nothing to review yet. Play some games first!") if @mode == "review" && current_player.review_questions(@topic).empty?
    return redirect_to(groups_path, notice: "That group challenge has finished.") if @mode == "group" && !group_round
    return redirect_to(groups_path, notice: "That head to head has been played or has run out.") if @mode == "head_to_head" && !head_to_head
    return redirect_to(live_game_path(params[:live].to_s)) if @mode == "live" && !live_game
    return redirect_to(challenge_path) if @mode == "daily" && (!daily_test || current_player.daily_game(@daily_test))

    @level = game_level
    @best = best_to_beat
    @ghost = @head_to_head.ghost if @mode == "head_to_head" && @head_to_head.sent?
    @live = live_details if @mode == "live"
    remember_topic @topic unless @mode.in?(%w[ group head_to_head live daily ])
    @question_sets = question_sets
    @question_sets.each do |set|
      set[:questions] = set[:questions].map { |question| @topic.with_solution(question) }
      set[:ticket] = Attempt::GameTicket.issue(owner: player_key, topic: @topic.key, level: @level, mode: @mode, round: @round,
        head_to_head: @head_to_head, live_game: @live_game, day: (@daily_test.day if @daily_test), **set.slice(:id, :questions))
    end
  end

  private
    def game_mode
      if params[:round].present? then "group"
      elsif params[:head_to_head].present? then "head_to_head"
      elsif params[:live].present? then "live"
      elsif params[:daily].present? then "daily"
      elsif params[:mixed].present? then "mixed"
      elsif params[:review].present? then "review"
      else "practice"
      end
    end

    def game_level
      case @mode
      when "practice" then level_from_params(@topic) || current_level(@topic)
      when "group" then @round.challenge.level
      when "head_to_head" then @head_to_head.level
      when "live" then @live_game.level
      when "daily" then @daily_test.level
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

    # One the player is in and whose go it is, in this topic
    def head_to_head
      @head_to_head = current_player.head_to_heads.find_by(id: params[:head_to_head])
      @head_to_head = nil unless @head_to_head&.topic_module == @topic && @head_to_head.turn?(current_player)
      @head_to_head
    end

    # Today's daily challenge of the kind asked for (?daily=1 is the Daily Tables Test, from before there was another),
    # if it's in this topic
    def daily_test
      kind = params[:daily] == "1" ? "tables" : params[:daily].to_s
      @daily_test = DailyTest.new(current_player.today, kind) if DailyTest::KINDS.dig(kind, :topic) == @topic
    end

    # A started live game in this topic that the player is in and hasn't played yet, before its minute is up
    def live_game
      game = LiveGame.find_by(code: params[:live].to_s)
      @live_game = game if game&.topic_module == @topic && game.running? && (player = game.player_for(current_player)) && !player.played?
    end

    # When it starts, from now, so every device counts down to the same moment, and who else is playing
    def live_details
      rivals = @live_game.players.includes(:user).reject { |player| player.user_id == current_player.id }
      { id: @live_game.id, me: current_player.id, pass: @live_game.pass_for(current_player), power: @live_game.power?,
        powerUps: (LiveGame::POWER_UPS if @live_game.power?), boxEveryMs: LiveGame::BOX_EVERY.in_milliseconds, boxes: LiveGame::BOXES, startsInMs: ((@live_game.starts_at - Time.current) * 1000).round,
        rivals: rivals.map { |player| { id: player.user_id, name: player.user.display_name } } }
    end

    # A level's best, or the challenger's score for their opponent
    def best_to_beat
      case @mode
      when "practice" then current_player.best_score(@topic, @level)
      when "head_to_head" then @head_to_head.sent? ? @head_to_head.challenger_attempt.score : 0
      else 0
      end
    end

    def question_sets
      case @mode
      when "review" then current_player.review_sets(topic: @topic)
      when "group" then [ { id: SecureRandom.hex(16), questions: @round.questions } ]
      when "head_to_head" then [ { id: SecureRandom.hex(16), questions: @head_to_head.questions } ]
      when "live" then [ { id: SecureRandom.hex(16), questions: @live_game.questions } ]
      when "daily" then [ { id: SecureRandom.hex(16), questions: @daily_test.questions } ]
      else current_player.question_sets(topic: @topic, level: @level, mix: @mode == "mixed" ? :all_levels : :level_only)
      end
    end
end
