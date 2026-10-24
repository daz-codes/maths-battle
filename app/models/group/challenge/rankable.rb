# A challenge's leaderboards. A round's ranks each player's first go at it, as later goes are just practice
# (they've seen the questions by then): by score, then fewer wrong answers, then who played first. An every day
# challenge also has the week's, from each player's first go each day, ranked by their total or their best day.
# Players who've left the group drop off. Only scores saved before the round ended count; device clocks
# are kept for personal history but never decide which competitive go counts
module Group::Challenge::Rankable
  extend ActiveSupport::Concern

  Entry = Data.define(:rank, :user, :attempt) do
    def score = attempt.score
    def wrong = attempt.answered - attempt.correct
  end

  WeekEntry = Data.define(:rank, :user, :total, :best, :days)

  def leaderboard(for_round = round, attempts: nil)
    return [] unless for_round

    goes = (attempts || Group::Round.first_goes([ for_round ])).select { |attempt| for_round.counts?(attempt) }
    ranked = goes.sort_by { |attempt| [ -attempt.score, attempt.answered - attempt.correct, attempt.created_at, attempt.id ] }
    entries = ranked.map { |attempt| Entry.new(rank: nil, user: attempt.user, attempt: attempt) }
    with_ranks(entries) { |entry| [ entry.score, entry.wrong ] }
  end

  def entry_for(user, for_round = round)
    leaderboard(for_round).find { |entry| entry.user == user }
  end

  # by: :total (every day played adds up) or :best (one great day)
  def week_leaderboard(by: :total)
    week_rounds = rounds.where(day: leaderboard_week).select(:id, :challenge_id, :day)
    week_rounds.each { |week_round| week_round.association(:challenge).target = self }
    by_id = week_rounds.index_by(&:id)
    goes = Group::Round.first_goes(week_rounds).select { |attempt| by_id.fetch(attempt.round_id).counts?(attempt) }
    entries = goes.group_by(&:user).map do |user, attempts|
      scores = attempts.map(&:score)
      WeekEntry.new(rank: nil, user: user, total: scores.sum, best: scores.max, days: scores.size)
    end
    ordered = entries.sort_by { |entry| by == :best ? [ -entry.best, -entry.total ] : [ -entry.total, -entry.best ] }
    with_ranks(ordered) { |entry| by == :best ? [ entry.best, entry.total ] : [ entry.total, entry.best ] }
  end

  private
    # Places, with ties (the same result by the block) sharing the place of the first of them: 1, 2, 2, 4
    def with_ranks(entries, &result)
      entries.each_with_index.each_with_object([]) do |(entry, index), ranked|
        tied = index.positive? && result.call(entry) == result.call(entries[index - 1])
        ranked << entry.with(rank: tied ? ranked.last.rank : index + 1)
      end
    end
end
