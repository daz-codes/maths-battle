module GroupsHelper
  # "Ends in 3 days", "Open until it's closed", "Ended 12 Oct", and for an every day one "🔁 Every day · …"
  def challenge_status(challenge)
    status =
      if !challenge.open? then "Ended #{l(challenge.ended_at.to_date, format: :short)}"
      elsif challenge.ends_at then "Ends in #{distance_of_time_in_words_to_now(challenge.ends_at)}"
      else challenge.daily? ? "Until it's closed" : "Open until it's closed"
      end
    challenge.daily? ? "🔁 Every day · #{status}" : status
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

  # Every topic's levels, for choosing a challenge's, grouped by topic: "Times tables, level 2: Tables 2–12"
  # (times_tables:2). The topic is in each option too, as a closed menu shows only the one chosen
  def topic_level_options(selected)
    grouped = Topic::ALL.to_h do |topic|
      options = topic.levels.map { |level| [ "#{topic.title}, level #{level[:number]}: #{level[:name]}", "#{topic.key}:#{level[:number]}" ] }
      [ "#{topic.emoji} #{topic.title}", options ]
    end
    grouped_options_for_select(grouped, selected)
  end
end
