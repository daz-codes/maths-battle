class AttemptsController < ApplicationController
  allow_unauthenticated_access only: :create
  rate_limit to: 20, within: 1.minute, only: :create

  def create
    results = results_param
    mode = Attempt::GameTicket.verify!(params.dig(:attempt, :ticket), owner: player_key,
      topic: topic_param, level: level_param, client_id: params.dig(:attempt, :client_id), results: results)
    player.update_time_zone(params.dig(:attempt, :time_zone))
    attempt = Attempt.record!(user: player, topic: topic_param, level: level_param, results: results, mode: mode, **upload_params)
    forget_level(attempt.topic_module) if attempt.levelled_up
    render json: { url: attempt_path(attempt) }, status: :created
  rescue Attempt::Invalid => error
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def show
    @attempt = Current.user.attempts.find(params[:id])
  end

  private
    # Guests' first saved test gives them an account and a session on this device
    def player
      @player ||= resume_or_start_guest_session.user
    end

    def topic_param
      params.dig(:attempt, :topic) || Topic.default.key
    end

    def level_param
      params.dig(:attempt, :level) || 1
    end

    # Games played offline arrive later, with an id made on the device and the time they were played
    def upload_params
      params.fetch(:attempt, {}).permit(:client_id, :played_at).to_h.symbolize_keys
    end

    # Anything but a list (like a hash with numbered keys) goes through as it is, to be refused as not a list
    def results_param
      results = params.fetch(:attempt, {}).permit(results: Attempt::RESULT_FIELDS).fetch(:results, [])
      results.is_a?(Array) ? results.map(&:to_h) : results
    end
end
