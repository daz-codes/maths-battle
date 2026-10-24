# A live game's scores while it's being played: each player sends their score and gems as they change, and
# everyone in the game sees them. Just for show: the podium comes from the saved games (LiveGame::Startable)
# Players are known by the pass their game's page gives them (LiveGame#pass_for)
class LiveGameChannel < ApplicationCable::Channel
  # The most a game's answers could earn: every one right, lightning fast, at the top combo
  MAX_GEMS = Attempt::MAX_ANSWERS * (Attempt::RIGHT + Attempt::SPEED[:lightning]) * Attempt::COMBOS.values.max

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

    LiveGameChannel.broadcast_to @live_game, { player_id: @player.user_id, score: count(data["score"], Attempt::MAX_ANSWERS), gems: count(data["gems"], MAX_GEMS) }
  end

  private
    def count(value, most)
      Integer(value, exception: false).to_i.clamp(0, most)
    end
end
