module User::Scorable
  extend ActiveSupport::Concern

  # The best score in a topic's level, from its games
  def best_score(topic, level)
    attempts.at_level(topic, level).maximum(:score) || 0
  end
end
