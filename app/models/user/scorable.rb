# A player's bests: the best score and the most right in a topic's level, from its games, and the best score from any
# game they've played
module User::Scorable
  extend ActiveSupport::Concern

  def best_score(topic = nil, level = nil)
    games = topic ? attempts.at_level(topic, level) : attempts
    games.maximum(:score) || 0
  end

  def best_correct(topic, level)
    attempts.at_level(topic, level).maximum(:correct) || 0
  end
end
