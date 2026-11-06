class AttemptsController < ApplicationController
  allow_unauthenticated_access only: :create
  rate_limit to: 20, within: 1.minute, only: :create

  def create
    game = Attempt::GameTicket.verify!(params.dig(:attempt, :ticket), owner: player_key, client_id: params.dig(:attempt, :client_id),
      answers: list_param(:results, %i[ op a b given ms ]), claims: list_param(:claims, %i[ drop at ]))
    attempt = Attempt.record!(user: player, game: game, client_id: params.dig(:attempt, :client_id))
    render json: { url: attempt_path(attempt) }, status: :created
  rescue Attempt::Invalid => error
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def show
    @attempt = Current.user.attempts.find(params[:id])
    @live_game = @attempt.live_game
    @world = League.world(@attempt.played_on)
    @leagues = Current.user.leagues.order(:name)
  end

  private
    # Guests' first saved game gives them an account and a session on this device
    def player
      @player ||= resume_or_start_guest_session.user
    end

    # Anything but a list (like a hash with numbered keys) goes through as it is, to be refused as not a list
    def list_param(name, fields)
      list = params.fetch(:attempt, {}).permit(name => fields).fetch(name, [])
      list.is_a?(Array) ? list.map(&:to_h) : list
    end
end
