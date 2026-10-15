# The Wordle-style brag a player can send to friends. Never includes the questions or who the player is
class ShareText
  MAX_SQUARES = 40

  def initialize(attempt, url:)
    @attempt, @url = attempt, url
  end

  def to_s
    [ headline, stats, emoji_row, @url ].compact_blank.join("\n")
  end

  def headline
    "MatheMinute ✖️ #{@attempt.score} in 60s"
  end

  def stats
    "🔥 #{@attempt.streak} day streak  🏆 Best: #{@attempt.user.high_score}"
  end

  def emoji_row
    squares = @attempt.results.first(MAX_SQUARES).map { |r| r["correct"] ? "🟩" : "🟥" }.join
    @attempt.results.size > MAX_SQUARES ? "#{squares}…" : squares
  end

  def title
    "#{@attempt.score} in a minute! 🔥 #{@attempt.streak} day streak"
  end
end
