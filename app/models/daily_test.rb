# The daily challenges: one game a day of each kind, the same questions for everyone that day, made from the date.
# The Daily Tables Test is the classic times tables (level 2, tables 2 to 12), whatever level a player has reached;
# Patternz mixes every kind of sequence, so the pattern has to be spotted too. Each player's one go at each is
# compared with everyone else's that day: "You're in the top 10% today". The day is each player's own
class DailyTest
  KINDS = {
    "tables" => { name: "Daily Tables Test", about: "Times tables 2 to 12", topic: TimesTables, level: 2, mix: :level_only,
      first_day: Date.new(2026, 10, 25), seed: 0 },
    "patternz" => { name: "Patternz", about: "Spot the pattern and find the next number", topic: Sequences, level: Sequences.max_level,
      mix: :all_levels, first_day: Date.new(2026, 10, 26), seed: 1_000_000 }
  }

  # How a player's game stands among the day's: its place, how many have played, the top percentage it's in, and
  # the percentage of players it beat
  Standing = Data.define(:rank, :players, :top_percent, :beaten_percent) do
    def first? = rank == 1
  end

  attr_reader :day, :kind

  # Every kind, for a day
  def self.on(day)
    KINDS.keys.map { |kind| new(day, kind) }
  end

  # The kind whose games are in this topic
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

  def number
    (day - details[:first_day]).to_i + 1
  end

  # Unweighted (a new player's questions) and seeded by the day, so they're the same for everyone
  def questions
    User.new.questions(topic: topic, level: level, mix: details[:mix], random: Random.new(day.jd + details[:seed]))
  end

  def games
    Attempt.where(mode: "daily", played_on: day, topic: topic.key)
  end

  def players
    games.count
  end

  def standing_of(attempt)
    scores = games.pluck(:score)
    rank = scores.count { |score| score > attempt.score } + 1
    beaten = scores.count { |score| score < attempt.score }
    Standing.new(rank: rank, players: scores.size, top_percent: (100.0 * rank / scores.size).ceil, beaten_percent: (100 * beaten / scores.size))
  end

  private
    def details = KINDS.fetch(kind)
end
