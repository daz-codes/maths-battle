class AttemptsController < ApplicationController
  allow_unauthenticated_access only: :create
  rate_limit to: 20, within: 1.minute, only: :create

  def create
    attempt = Attempt.record!(user: player, topic: topic_param, results: results_param, **upload_params)
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
      resume_or_start_guest_session.user
    end

    def topic_param
      params.dig(:attempt, :topic) || Topic.default::TOPIC
    end

    # Games played offline arrive later, with an id made on the device and the time they were played
    def upload_params
      params.fetch(:attempt, {}).permit(:client_id, :played_at).to_h.symbolize_keys
    end

    def results_param
      params.fetch(:attempt, {}).permit(results: Attempt::RESULT_FIELDS).fetch(:results, []).map(&:to_h)
    end
end
