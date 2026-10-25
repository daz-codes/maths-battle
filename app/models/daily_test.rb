# The Daily Tables Test: one game a day of the classic times tables (level 2, tables 2 to 12), whatever level a
# player has reached. Everyone gets the same questions that day, made from the date, and each player's one go is
# compared with everyone else's that day: "You're in the top 10% today". The day is each player's own
class DailyTest
  TOPIC = TimesTables
  LEVEL = 2
  # The first one, numbered 1
  FIRST_DAY = Date.new(2026, 10, 25)

  # How a player's game stands among the day's: its place, how many have played, the top percentage it's in, and
  # the percentage of players it beat
  Standing = Data.define(:rank, :players, :top_percent, :beaten_percent) do
    def first? = rank == 1
  end

  attr_reader :day

  def initialize(day)
    @day = day
  end

  def number
    (day - FIRST_DAY).to_i + 1
  end

  # Unweighted (a new player's questions) and seeded by the day, so they're the same for everyone
  def questions
    User.new.questions(topic: TOPIC, level: LEVEL, random: Random.new(day.jd))
  end

  def games
    Attempt.where(mode: "daily", played_on: day)
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
end
