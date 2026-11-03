# The daily challenge: a game of each kind every day, played as often as anyone likes. Every game has new questions, balanced
# so each set is as hard as any other (DailyTest::Balancer), and a player's best game of the day is ranked against
# everyone else's best: "You're in the top 10% today". The Tables Test is the classic times tables (level 2, tables 2
# to 12), whatever level a player has reached. The day is each player's own.
#
# Patternz (every kind of sequence mixed) has been retired: its games are kept and still show, but it isn't played
class DailyTest
  KINDS = {
    "tables" => { name: "Tables Test", about: "Times tables 2 to 12", topic: TimesTables, level: 2,
      first_day: Date.new(2026, 10, 25) },
    "patternz" => { name: "Patternz", about: "Spot the pattern and find the next number", topic: Sequences, level: Sequences.max_level,
      first_day: Date.new(2026, 10, 26), retired: true }
  }
  # The kinds played now
  PLAYED = KINDS.reject { |_, details| details[:retired] }.keys

  # How a player's game stands among the day's: its place, how many have played, the top percentage it's in, and
  # the percentage of players it beat
  Standing = Data.define(:rank, :players, :top_percent, :beaten_percent) do
    def first? = rank == 1
  end

  # A day of a player's week at one kind, and their game that day, if they played
  Day = Data.define(:day, :attempt)

  attr_reader :day, :kind

  # Every kind played now, for a day
  def self.on(day)
    PLAYED.map { |kind| new(day, kind) }
  end

  # Today's one to play: the Tables Test
  def self.today_for(user)
    new(user.today, PLAYED.first)
  end

  # The kind whose games are in this topic, retired or not, so old games still show
  def self.kind_for(topic)
    KINDS.find { |_, details| details[:topic] == topic }&.first
  end

  def initialize(day, kind = "tables")
    @day, @kind = day, KINDS.key?(kind) ? kind : raise(ArgumentError, "No daily test called #{kind}")
  end

  def name = details[:name]
  def about = details[:about]
  def topic = details[:topic]
  def level = details[:level]
  def retired? = details[:retired].present?

  def number
    (day - details[:first_day]).to_i + 1
  end

  # A new set every game, as hard as everyone else's
  def questions(random: Random.new)
    Balancer.new(topic, level, day: day).questions(count: User::Practisable::QUESTION_COUNT, random: random)
  end

  def games
    Attempt.where(mode: "daily", played_on: day, topic: topic.key)
  end

  # How many have played today, however many games each
  def players
    games.distinct.count(:user_id)
  end

  # Where a game would put its player today: its score against everyone else's best
  def standing_of(attempt)
    others = games.where.not(user_id: attempt.user_id).group(:user_id).maximum(:score).values
    rank = others.count { |score| score > attempt.score } + 1
    beaten = others.count { |score| score < attempt.score }
    players = others.size + 1
    Standing.new(rank: rank, players: players, top_percent: (100.0 * rank / players).ceil, beaten_percent: (100 * beaten / players))
  end

  # The player's best game at this kind each day of the week up to this day, played or not. A game shown from
  # one of those days stands for its day, so it's the one highlighted
  def week_of(user, showing: nil)
    days = (day - 6)..day
    games = user.attempts.where(mode: "daily", topic: topic.key, played_on: days).order(:score, id: :desc).index_by(&:played_on)
    games[showing.played_on] = showing if showing
    days.map { |date| Day.new(day: date, attempt: games[date]) }
  end

  private
    def details = KINDS.fetch(kind)
end
