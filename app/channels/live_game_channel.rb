# A battle while it's being played: each player sends their score, how many they've got right and how many they've
# answered as they change, and everyone in the battle sees the scores. Just for show: the podium comes from the saved
# games (LiveGame::Startable). Each player's power-ups drop as they answer, and when they fall far behind, and only
# they can claim them (LiveGame::Droppable). Players are known by the pass their game's page gives them (LiveGame#pass_for)
class LiveGameChannel < ApplicationCable::Channel
  # The most a game's answers could score: every one right in a row, doubled
  MAX_SCORE = Attempt::Scorable::STEP * (1..Attempt::Recordable::MAX_ANSWERS).sum * 2

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

    score, correct = count(data["score"], MAX_SCORE), count(data["correct"], Attempt::Recordable::MAX_ANSWERS)
    @player.update_columns(live_score: score)
    LiveGameChannel.broadcast_to @live_game, { type: "score", player_id: @player.user_id, score: score, correct: correct }
    drops = @live_game.answered(@player, count(data["answered"], Attempt::Recordable::MAX_ANSWERS)) + @live_game.catch_up
    drops.each { |drop| LiveGameChannel.broadcast_to @live_game, { type: "drop", id: drop.id, for: drop.owner_id } }
  end

  def claim(data)
    drop = @live_game.claim(data["id"], @player)
    LiveGameChannel.broadcast_to @live_game, { type: "claimed", id: drop.id, power_up: drop.power_up, by: drop.claimed_by_id, target: drop.target_id, blocked: drop.blocked_ids } if drop
  end

  private
    def count(value, most)
      Integer(value, exception: false).to_i.clamp(0, most)
    end
end
