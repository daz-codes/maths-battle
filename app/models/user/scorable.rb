module User::Scorable
  # The best score in a topic, from its games
  def best_score(topic)
    attempts.in_topic(topic).maximum(:score) || 0
  end
end
