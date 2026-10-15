class AttemptsController < ApplicationController
  allow_unauthenticated_access only: :create
  rate_limit to: 20, within: 1.minute, only: :create

  def create
    attempt = Attempt.record!(user: resume_or_start_guest_session.user, topic: params.dig(:attempt, :topic) || TimesTables::TOPIC, results: results_param)
    render json: { url: attempt_path(attempt) }, status: :created
  rescue Attempt::Invalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def show
    @attempt = Current.user.attempts.find(params[:id])
    @feedback = @attempt.topic_module::Feedback.new(@attempt)
    @share_text = ShareText.new(@attempt, url: share_url(@attempt.share_token))
  end

  private
    def results_param
      params.fetch(:attempt, {}).permit(results: %i[ a b given ms ]).fetch(:results, []).map(&:to_h)
    end
end
