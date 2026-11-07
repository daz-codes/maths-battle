# A game's page: a solo game, or a battle's (?live=K7Q2M) once it's started, for one of its players who hasn't
# played it yet. Each gets its own ladder of questions, signed in its ticket (Attempt::GameTicket)
class GamesController < ApplicationController
  allow_unauthenticated_access

  def show
    if params[:live].present?
      @live_game = playable_live_game
      return redirect_to(live_game_path(params[:live].to_s)) unless @live_game
    end

    pools = Ladder.deal
    powers = @live_game ? [] : PowerUp.deal_solo
    id = SecureRandom.hex(16)
    @game = { id: id, ticket: Attempt::GameTicket.issue(owner: player_key, id: id, pools: pools, powers: powers, live_game: @live_game),
      pools: pools.map { |pool| pool.map { |question| Ladder.worked(question) } }, powers: powers, ladder: Ladder.rules, most: Attempt::Recordable::MAX_ANSWERS }
    @live = live_details if @live_game
    @best = current_player.persisted? ? current_player.best_score : 0
  end

  private
    # A started battle the player is in and hasn't played yet, before its minute is up
    def playable_live_game
      game = LiveGame.find_by_code(params[:live])
      game if game&.running? && (player = game.player_for(current_player)) && !player.played?
    end

    # When it starts, from now, so every device counts down to the same moment, and who else is playing
    def live_details
      rivals = @live_game.players.includes(:user).reject { |player| player.user_id == current_player.id }
      { me: current_player.id, pass: @live_game.pass_for(current_player), starSeconds: LiveGame::STAR_SECONDS, startsInMs: ((@live_game.starts_at - Time.current) * 1000).round,
        rivals: rivals.map { |player| { id: player.user_id, name: player.user.display_name } } }
    end
end
