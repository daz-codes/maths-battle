module User::Scorable
  # The best score in a topic's level, from its games
  def best_score(topic, level)
    attempts.in_topic(topic, level).maximum(:score) || 0
  end
end
