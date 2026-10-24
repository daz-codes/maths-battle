# A player's bests: the best score and most gems in a topic's level, from its games, and the most gems from any one
# game they've played
module User::Scorable
  extend ActiveSupport::Concern

  def best_score(topic, level)
    attempts.at_level(topic, level).maximum(:score) || 0
  end

  def most_gems(topic = nil, level = nil)
    games = topic ? attempts.at_level(topic, level) : attempts
    games.maximum(:gems) || 0
  end
end
