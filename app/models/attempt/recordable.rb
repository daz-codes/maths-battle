# Saves a game from the answers the browser sent, once its ticket has checked them (Attempt::GameTicket). How many
# were right and the score are worked out here rather than trusted, and answers that couldn't have come from a real
# game are refused. A battle's game also takes the Streak breakers other players hit it with (LiveGame::Droppable)
module Attempt::Recordable
  extend ActiveSupport::Concern

  MAX_ANSWERS = 300
  # The game lasts two minutes; allow a little slack for the end-of-game POST
  MAX_TOTAL_MS = 125_000
  # Anything the keypad can type, unfinished answers like "0." included: those are just wrong
  TYPED_ANSWER = %r{\A[0-9.]{0,12}\z}

  class Invalid < StandardError; end

  included do
    before_create :score_results, :set_played_on, :record_best
  end

  class_methods do
    # A game sent again with the same client id (a retried upload) is only recorded once
    def record!(user:, game:, client_id:)
      if existing = already_recorded(user, client_id)
        return existing
      end

      live_game = check_live_game(user, game) if game.mode == "battle"
      powers = live_game ? live_game.powers_in(user, game.results) : game.powers
      check_total_time(game.results, powers)

      transaction do
        user.lock!
        user.attempts.create!(mode: game.mode, results: game.results, powers: powers, top_tier: game.top_tier, client_id: client_id.presence)
          .tap { |attempt| live_game&.played(attempt) }
          .tap(&:award_badges)
      end
    rescue ActiveRecord::RecordNotUnique
      already_recorded(user, client_id) || raise
    end

    private
      def already_recorded(user, client_id)
        user.attempts.find_by(client_id: client_id) if client_id.present?
      end

      def check_live_game(user, game)
        live_game = LiveGame.find_by(id: game.live_game_id)
        raise Invalid, "That battle isn't there any more" unless live_game
        raise Invalid, "Only its players can play a battle" unless live_game.player?(user)
        raise Invalid, "That battle hasn't started" unless live_game.started?
        live_game
      end

      # Extra time makes the game longer
      def check_total_time(results, powers)
        most = MAX_TOTAL_MS + powers.sum { |power| PowerUp.extra_ms(power["kind"]) }
        raise Invalid, "Bad timing" if results.sum { |result| result["ms"] } > most
      end
  end

  private
    def score_results
      self.correct = results.count { |result| result["correct"] }
      self.answered = results.count { |result| !result["skip"] }
      self.score = tally.score
      self.best_streak = tally.best_streak
    end

    # Today in the leagues, which everyone shares
    def set_played_on
      self.played_at ||= Time.current
      self.played_on = League.day(played_at)
    end

    def record_best
      self.new_best = score.positive? && score > user.best_score
    end
end
