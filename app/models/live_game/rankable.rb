# The podium: each player's game by score, then fewer wrong answers, or in a Power game by the gems its answers
# earned (not its bonuses), then score. Ties share a place. Players still playing (or who never did) come after
module LiveGame::Rankable
  extend ActiveSupport::Concern

  Place = Data.define(:rank, :user, :attempt) do
    def score = attempt&.score
    def gems = attempt&.answer_gems
  end

  def podium
    finished, waiting = players.includes(:user, :attempt).partition(&:played?)
    ranked = finished.sort_by { |player| [ *(-player.attempt.answer_gems if power?), -player.attempt.score, player.attempt.answered - player.attempt.score, player.attempt.created_at ] }
    places = ranked.each_with_index.each_with_object([]) do |(player, index), list|
      tied = index.positive? && result(player) == result(ranked[index - 1])
      list << Place.new(rank: tied ? list.last.rank : index + 1, user: player.user, attempt: player.attempt)
    end
    places + waiting.map { |player| Place.new(rank: nil, user: player.user, attempt: nil) }
  end

  def place_of(user)
    podium.find { |place| place.user.id == user.id }
  end

  private
    def result(player)
      [ (player.attempt.answer_gems if power?), player.attempt.score, player.attempt.answered - player.attempt.score ]
    end
end
