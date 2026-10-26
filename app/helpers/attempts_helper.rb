module AttemptsHelper
  # Back from a game's results to where it was played from: Practice (to change level or topic), the Daily
  # Challenge, its group, or Compete
  def results_back_link(attempt)
    label, path =
      if attempt.daily_test? then [ "Daily Challenge", challenge_path ]
      elsif attempt.group? && (group = attempt.round&.challenge&.group) then [ group.name, group_path(group) ]
      elsif attempt.head_to_head? || attempt.live? then [ "Compete", groups_path ]
      else [ "Practice", practice_path ]
      end
    link_to "← #{label}", path, class: "back-link"
  end
end
