# Playing again with the same players. Once it's started, the host can make the next game, at the same topic, level
# and mode with new questions, and everyone still looking at the podium or their result is taken to its lobby and
# joined (LiveRematchController). Anyone who comes back later finds a Play again button instead
module LiveGame::Rematchable
  extend ActiveSupport::Concern

  included do
    belongs_to :rematch, class_name: "LiveGame", optional: true
  end

  # The next game, made once however many times the host asks
  def play_again!
    made = with_lock do
      return rematch if rematch
      return unless started?

      update!(rematch: LiveGame.make(host: host, topic: topic_module, level: level, mode: mode))
    end
    broadcast_rematch if made
    rematch
  end

  private
    def broadcast_rematch
      Turbo::StreamsChannel.broadcast_replace_to self, target: "live-again", partial: "live_games/again", locals: { live_game: self, user: nil, joining: true }
    end
end
