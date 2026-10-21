# Who won. A game counts once both players have had their go: the challenger's first, then the opponent's, saved
# before the challenge ran out (a late offline game is kept in their history, but changes nothing). The higher score
# wins, then fewer wrong answers; anything else is a draw
module HeadToHead::Decidable
  extend ActiveSupport::Concern

  def sent?
    challenger_attempt_id.present?
  end

  def decided?
    decided_at.present?
  end

  def open?
    sent? && !decided? && expires_at.future?
  end

  def ran_out?
    sent? && !decided? && expires_at.past?
  end

  # Their go is waiting: the challenger's before it's sent, the opponent's until it runs out
  def turn?(user)
    if user.id == challenger_id then !sent?
    elsif user.id == opponent_id then open?
    end
  end

  # Records the first go of each player, deciding it once both have played
  def played(attempt)
    with_lock do
      if attempt.user_id == challenger_id && !sent?
        update!(challenger_attempt: attempt, expires_at: HeadToHead::TIME_TO_PLAY.from_now)
      elsif attempt.user_id == opponent_id && open?
        update!(opponent_attempt: attempt, decided_at: Time.current, winner: winner_between(challenger_attempt, attempt))
      end
    end
  end

  # :won, :lost or :drew, for one of its players
  def result_for(user)
    return unless decided?

    if winner_id.nil? then :drew
    elsif winner_id == user.id then :won
    else :lost
    end
  end

  private
    def winner_between(challenger_go, opponent_go)
      case [ challenger_go.score, -wrong(challenger_go) ] <=> [ opponent_go.score, -wrong(opponent_go) ]
      when 1 then challenger
      when -1 then opponent
      end
    end

    def wrong(attempt)
      attempt.answered - attempt.score
    end
end
