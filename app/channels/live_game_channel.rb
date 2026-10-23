# A live game's scores while it's being played: each player sends their score as it goes up, and everyone in the
# game sees it. Just for show: the podium comes from the saved games (LiveGame::Startable)
# Players are known by the pass their game's page gives them (LiveGame#pass_for)
class LiveGameChannel < ApplicationCable::Channel
  def subscribed
    @player = LiveGame.player_from_pass(params[:pass])
    return reject unless @player

    @live_game = @player.live_game
    stream_for @live_game
  end

  # Players subscribe in the lobby, before the host starts it, so it's looked at again until it has
  def score(data)
    @live_game.reload unless @live_game.started?
    return unless @live_game.running?

    LiveGameChannel.broadcast_to @live_game, { player_id: @player.user_id, score: Integer(data["score"], exception: false).to_i.clamp(0, Attempt::MAX_ANSWERS) }
  end
end
