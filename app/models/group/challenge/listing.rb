# Cards and waiting challenges for a member, loaded together. Historical question sets and replay answers
# aren't needed by these pages. Reading a list never creates today's rounds
class Group::Challenge::Listing
  Card = Data.define(:challenge, :entry, :player, :played) do
    def playable? = player && challenge.open?
    def waiting? = playable? && !played
  end

  attr_reader :cards

  def initialize(challenges, user:)
    challenges = challenges.to_a
    by_id = challenges.index_by(&:id)
    scope = challenges.reduce(Group::Round.none) { |all, challenge| all.or(challenge.display_round_scope) }
    rounds = scope.select(:id, :challenge_id, :day).to_a
    rounds.each { |round| round.association(:challenge).target = by_id.fetch(round.challenge_id) }
    by_challenge = rounds.index_by(&:challenge_id)
    attempts = Group::Round.first_goes(rounds).group_by(&:round_id)

    @cards = challenges.map do |challenge|
      round = by_challenge[challenge.id]
      goes = attempts.fetch(round&.id, [])
      entry = challenge.leaderboard(round, attempts: goes).find { |row| row.user.id == user.id }
      player = challenge.owner_plays? || challenge.group.owner_id != user.id
      Card.new(challenge:, entry:, player:, played: goes.any? { |attempt| attempt.user_id == user.id })
    end
  end

  def waiting_challenges
    cards.select(&:waiting?).map(&:challenge)
  end
end
