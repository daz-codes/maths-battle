# What a head to head tells its players: the opponent when it's sent to them, and the challenger when it's been
# played back, win or lose. Like a group's news, only on devices with reminders on and never at night
# (User::Notifiable)
module HeadToHead::Announceable
  extend ActiveSupport::Concern

  included do
    after_commit :announce_sent, on: %i[ create update ], if: -> { saved_change_to_challenger_attempt_id? && sent? }
    after_commit :announce_result, on: :update, if: -> { saved_change_to_decided_at? && decided? }
  end

  private
    def announce_sent
      opponent.notify_later(title: "⚔️ #{challenger.display_name} has challenged you!",
        body: "Beat #{challenger_attempt.score} at #{title}. Same questions, one go each.", url: link)
    end

    def announce_result
      challenger_score, opponent_score = challenger_attempt.score, opponent_attempt.score
      heading = { won: "🏆 You beat #{opponent.display_name}!", lost: "😮 #{opponent.display_name} beat you!",
        drew: "🤝 A draw with #{opponent.display_name}" }.fetch(result_for(challenger))
      challenger.notify_later(title: heading, body: "#{challenger_score}–#{opponent_score} at #{title}. Fancy a rematch?", url: link)
    end

    def link
      Rails.application.routes.url_helpers.head_to_head_path(self)
    end
end
