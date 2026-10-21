# Challenging a rival to a head to head: sending a game just played (?attempt=), or a new one at the player's topic
# and level, or a rematch's, played first and then sent. Its page shows both scores and who won
class HeadToHeadsController < ApplicationController
  rate_limit to: 20, within: 10.minutes, only: :create

  # Who to send a game to
  def new
    @attempt = Current.user.attempts.find(params[:attempt])
    return redirect_to(attempt_path(@attempt)) unless @attempt.sendable?

    @rivals = Current.user.rivals.order(:name, :username)
  end

  def create
    opponent = Current.user.rivals.find(params[:opponent_id])
    if params[:attempt_id].present?
      attempt = Current.user.attempts.find(params[:attempt_id])
      return redirect_to(attempt_path(attempt)) unless attempt.sendable?

      head_to_head = HeadToHead.from_game(attempt, opponent: opponent)
      redirect_to head_to_head, notice: "Sent! #{opponent.display_name} has #{HeadToHead::TIME_TO_PLAY.inspect} to beat your #{attempt.score}."
    else
      topic = Topic.find(params[:topic]) || current_topic
      level = params[:level].present? ? params[:level].to_i : current_level(topic)
      head_to_head = HeadToHead.fresh(challenger: Current.user, opponent: opponent, topic: topic, level: level, mixed: params[:mixed] == "1")
      redirect_to play_path(topic.slug, head_to_head: head_to_head.id)
    end
  rescue ActiveRecord::RecordInvalid
    redirect_to groups_path, notice: "That head to head couldn't be set up."
  end

  def show
    @head_to_head = Current.user.head_to_heads.includes(:challenger, :opponent, :challenger_attempt, :opponent_attempt).find(params[:id])
    @rival = @head_to_head.rival_of(Current.user)
    @record = Current.user.head_to_head_record(@rival)
  end
end
