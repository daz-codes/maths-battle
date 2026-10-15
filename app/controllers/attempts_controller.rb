class AttemptsController < ApplicationController
  def create
    attempt = Attempt.record!(user: Current.user, topic: params.dig(:attempt, :topic) || TimesTables::TOPIC, results: results_param)
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
