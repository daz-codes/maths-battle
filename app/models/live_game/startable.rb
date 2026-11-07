# Starting together. The host starts it with a few seconds' lead, so every device has loaded the game by then;
# each counts down to the same moment and plays the same two minutes, ending together. Scores sent while playing are
# just for show (LiveGameChannel): what counts is each saved game, checked on the server like any other
module LiveGame::Startable
  extend ActiveSupport::Concern

  START_LEAD = 6.seconds
  DURATION = 2.minutes
  # Saving a game takes a moment after it ends, and a dropped connection a little longer
  SAVE_TIME = 2.minutes

  def started?
    starts_at.present?
  end

  def running?
    started? && Time.current < ends_at
  end

  def over?
    started? && Time.current >= ends_at
  end

  def ends_at
    starts_at + DURATION if started?
  end

  # The host, once someone else has joined
  def start!
    with_lock do
      return false if started? || players.count < 2

      update!(starts_at: START_LEAD.from_now)
    end
    broadcast_start
    true
  end

  # A player's first game, saved in time, is their place on the podium
  def played(attempt)
    player = player_for(attempt.user)
    return unless player && !player.played? && attempt.created_at <= ends_at + SAVE_TIME

    player.update!(attempt: attempt)
    award_winners
    broadcast_podium
  end

  private
    # Once everyone's game is in, whoever came first (a tie shares it), if they scored
    def award_winners
      places = podium
      return unless places.many? && places.all?(&:attempt)

      places.select { |place| place.rank == 1 && place.score.positive? }.each { |place| Badge.award(place.user, "first_win", attempt: place.attempt) }
    end

    # Every page open on the game: the lobby's list of players, its start, and the podium
    def broadcast_lobby
      Turbo::StreamsChannel.broadcast_replace_to self, target: "live-players", partial: "live_games/players", locals: { live_game: self }
    end

    def broadcast_start
      Turbo::StreamsChannel.broadcast_replace_to self, target: "live-status", partial: "live_games/started", locals: { live_game: self }
    end

    def broadcast_podium
      Turbo::StreamsChannel.broadcast_replace_to self, target: "live-podium", partial: "live_games/podium", locals: { live_game: self }
    end
end
