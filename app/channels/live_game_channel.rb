# A live game while it's being played: each player sends their score and gems as they change, and everyone in the
# game sees them. Just for show: the podium comes from the saved games (LiveGame::Startable). In a Power game it
# also deals each player's boxes and passes on the power-ups they use (LiveGame::Powerable). Players are known by
# the pass their game's page gives them (LiveGame#pass_for)
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

    score, gems = count(data["score"], Attempt::MAX_ANSWERS), count(data["gems"], MAX_GEMS)
    @player.update_columns(live_gems: gems) if @live_game.power?
    LiveGameChannel.broadcast_to @live_game, { type: "score", player_id: @player.user_id, score: score, gems: gems }
  end

  # Only to the player who opened it
  def open_box
    @live_game.reload unless @live_game.started?
    power_up = @live_game.open_box(@player)
    transmit({ type: "box", power_up: power_up }) if power_up
  end

  def use_power_up
    used = @live_game.use_power_up(@player)
    LiveGameChannel.broadcast_to @live_game, used.merge(type: "power_up") if used
  end

  private
    def count(value, most)
      Integer(value, exception: false).to_i.clamp(0, most)
    end
end
