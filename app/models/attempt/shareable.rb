# A Wordle-style brag a player can send to friends, and the public page it links to.
# Never includes the questions or anything about who the player is
module Attempt::Shareable
  extend ActiveSupport::Concern

  MAX_SQUARES = 40

  included do
    has_secure_token :share_token
  end

  def share_text(url)
    [ share_headline, share_stats, emoji_row, url ].compact_blank.join("\n")
  end

  def share_title
    "#{score} in a minute! 🔥 #{streak} day streak"
  end

  def share_headline
    "MatheMinute #{topic_module::EMOJI} #{topic_module::NAME}: #{score} in 60s"
  end

  def share_stats
    "🔥 #{streak} day streak  🏆 Best: #{user.best_score(topic_module)}"
  end

  def emoji_row
    squares = results.first(MAX_SQUARES).map { |result| result["correct"] ? "🟩" : "🟥" }.join
    results.size > MAX_SQUARES ? "#{squares}…" : squares
  end
end
