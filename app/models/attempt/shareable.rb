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

  def share_description
    "A MatheMinute player got #{score} #{topic_module.title.downcase} right in 60 seconds. Can you beat it?"
  end

  def share_headline
    "MatheMinute #{topic_module.emoji} #{topic_and_level}: #{score} in 60s"
  end

  def share_stats
    "🔥 #{streak} day streak  🏆 Best: #{best_score}"
  end

  # "Times tables, level 3" where a topic has levels
  def topic_and_level
    if daily_challenge? then "#{topic_module.title}, daily challenge"
    elsif review? then "#{topic_module.title}, review"
    elsif group? then "#{topic_module.title}, level #{level}, group challenge"
    elsif topic_module.levels.many? then "#{topic_module.title}, level #{level}"
    else topic_module.title
    end
  end

  def emoji_row
    squares = results.first(MAX_SQUARES).map { |result| result["correct"] ? "🟩" : "🟥" }.join
    results.size > MAX_SQUARES ? "#{squares}…" : squares
  end
end
