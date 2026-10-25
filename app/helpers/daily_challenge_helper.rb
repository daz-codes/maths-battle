module DailyChallengeHelper
  # "You're in the top 10% today" for the top half, then how many it beat, or the top score
  def daily_standing_message(standing)
    if standing.players == 1 then "You're the first to play today!"
    elsif standing.first? then "Top score today!"
    elsif standing.top_percent <= 50 then "You're in the top #{standing.top_percent}% today"
    elsif standing.beaten_percent.positive? then "You beat #{standing.beaten_percent}% of players today"
    else "Tomorrow's a new test!"
    end
  end
end
