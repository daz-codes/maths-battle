module HeadToHeadsHelper
  # "Won 5 · Lost 2 · Drew 1", leaving out what hasn't happened
  def record_line(record)
    return "No games yet" if record.played.zero?

    { "Won" => record.won, "Lost" => record.lost, "Drew" => record.drew }.filter_map { |word, count| "#{word} #{count}" if count.positive? }.join(" · ")
  end

  # Where a head to head stands, for one of its players
  def head_to_head_status(head_to_head, user)
    rival = head_to_head.rival_of(user)&.display_name
    if head_to_head.link?
      head_to_head.open? ? "Sent as a link · #{time_left(head_to_head)}" : "No one took up your link in time"
    elsif head_to_head.decided?
      mine, theirs = head_to_head.attempt_of(user).score, head_to_head.attempt_of(head_to_head.rival_of(user)).score
      { won: "You won #{mine}–#{theirs}", lost: "#{rival} won #{theirs}–#{mine}", drew: "A draw, #{mine}–#{theirs}" }.fetch(head_to_head.result_for(user))
    elsif !head_to_head.sent?
      user.id == head_to_head.challenger_id ? "Play first, then it's sent to #{rival}" : "Waiting for #{rival} to play"
    elsif head_to_head.ran_out?
      user.id == head_to_head.challenger_id ? "#{rival} didn't play in time" : "Ran out before you played"
    elsif user.id == head_to_head.challenger_id
      "Waiting for #{rival} · #{time_left(head_to_head)}"
    else
      "Beat #{head_to_head.challenger_attempt.score} · #{time_left(head_to_head)}"
    end
  end

  # On the results page of a head to head game
  def head_to_head_result_message(attempt, head_to_head)
    if head_to_head.nil?
      "Saved to your history: this head to head was over before your game was saved."
    elsif head_to_head.decided? || head_to_head.link?
      head_to_head_status(head_to_head, attempt.user)
    else
      "Sent! #{head_to_head.rival_of(attempt.user).display_name} has #{HeadToHead::TIME_TO_PLAY.inspect} to beat your #{attempt.score}."
    end
  end

  def time_left(head_to_head)
    "#{distance_of_time_in_words_to_now(head_to_head.expires_at)} left"
  end
end
