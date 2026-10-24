module GroupsHelper
  # "Ends in 3 days", "Open until it's closed", "Ended 12 Oct", and for an every day one "Every day · …" with its icon
  def challenge_status(challenge)
    status =
      if !challenge.open? then "Ended #{l(challenge.ended_at.to_date, format: :short)}"
      elsif challenge.ends_at then "Ends in #{distance_of_time_in_words_to_now(challenge.ends_at)}"
      else challenge.daily? ? "Until it's closed" : "Open until it's closed"
      end
    challenge.daily? ? safe_join([ icon(:review), " Every day · #{status}" ]) : status
  end

  # "3rd of 12"
  def place(entry, leaderboard)
    "#{entry.rank.ordinalize} of #{leaderboard.size}"
  end

  def group_result_message(attempt, leaderboard)
    round = attempt.round
    challenge = round.challenge
    if entry = leaderboard.find { |row| row.attempt == attempt }
      day = round.day == challenge.group.today ? " today" : " on #{l(round.day, format: :short)}" if challenge.daily?
      "You're #{place(entry, leaderboard)}#{day} in #{challenge.group.name}"
    elsif !round.counts?(attempt)
      "Saved to your history after the round ended: this score won't change the leaderboard."
    else
      "Just for practice: your first saved score is the one that counts."
    end
  end

  # The levels to choose from for a challenge's topic, with their names, then every level mixed (not for a live game)
  def challenge_level_options(topic, selected, mixed: true)
    levels = topic.levels.map { |level| [ "Level #{level[:number]}: #{level[:name]}", level[:number] ] }
    options_for_select(levels + (mixed ? [ [ "Mixed: every level", "mixed" ] ] : []), selected)
  end

  # Each topic's level names, so the level menu can follow the topic chosen (challenge-levels controller)
  def challenge_level_names
    Topic::ALL.to_h { |topic| [ topic.key, topic.levels.map { |level| level[:name] } ] }
  end
end
