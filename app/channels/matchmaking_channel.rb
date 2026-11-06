# The Find a match page, open: while it's subscribed its player is looking for a battle (MatchRequest). When they're
# matched, each player's page is sent to the game; everyone looking sees how many are
class MatchmakingChannel < ApplicationCable::Channel
  STREAM = "matchmaking"

  def subscribed
    return reject unless current_user

    stream_for current_user
    stream_from STREAM
    if (live_game = MatchRequest.enter(current_user))
      live_game.players.each { |player| MatchmakingChannel.broadcast_to player.user, { type: "matched", code: live_game.code } }
    end
    MatchmakingChannel.announce_waiting
  end

  # Still here: a page that's open keeps its place
  def waiting
    MatchRequest.where(user: current_user).touch_all
  end

  def unsubscribed
    MatchRequest.leave(current_user) if current_user
    MatchmakingChannel.announce_waiting
  end

  def self.announce_waiting
    ActionCable.server.broadcast STREAM, { type: "waiting", count: MatchRequest.waiting_count }
  end
end
