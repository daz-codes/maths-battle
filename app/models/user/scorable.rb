module User::Scorable
  # Returns true when the score beats the previous best
  def record_score!(score)
    return false unless score > high_score

    update!(high_score: score)
    true
  end
end
