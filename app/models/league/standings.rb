# A league's table for a day: each player's best score that day, highest first, tied players sharing a place. The
# world league is everyone with a name (a guest who hasn't given one isn't shown); a league is just its members
class League::Standings
  Entry = Data.define(:rank, :user, :score)

  # The world league shows its top players, and each player where they are
  SHOWN = 50

  attr_reader :day

  def initialize(day:, users: nil)
    @day, @users = day, users
  end

  def entries(limit: SHOWN)
    @entries ||= {}
    @entries[limit] ||= begin
      bests = best_scores.order(Arel.sql("MAX(attempts.score) DESC")).limit(limit).maximum(:score)
      users = User.where(id: bests.keys).index_by(&:id)
      rank = 0
      bests.each_with_index.map do |(user_id, score), index|
        rank = index + 1 unless index.positive? && score == bests.values[index - 1]
        Entry.new(rank:, user: users.fetch(user_id), score:)
      end
    end
  end

  # Where they are today, shown or not. Nil if they haven't played today
  def entry_for(user)
    return unless user&.persisted?

    score = scope.where(user_id: user.id).maximum(:score)
    Entry.new(rank: best_scores.having("MAX(attempts.score) > ?", score).count.size + 1, user:, score:) if score
  end

  # How many have played today
  def size
    scope.distinct.count(:user_id)
  end

  def leader
    entries(limit: 1).first
  end

  private
    def scope
      attempts = Attempt.on(day).joins(:user).merge(User.named)
      @users ? attempts.where(user_id: @users.select(:id)) : attempts
    end

    def best_scores
      scope.group(:user_id)
    end
end
