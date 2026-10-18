# The daily challenge, in topics that play by medals: one game a day, mixing questions from every level up to
# the player's. It has its own best score, as it's played across levels
module User::Challengeable
  extend ActiveSupport::Concern

  # The day's daily challenge, if it's been played
  def daily_challenge_on(topic, day = today)
    attempts.in_topic(topic).daily_challenges.find_by(played_on: day)
  end

  def best_daily_challenge(topic)
    attempts.in_topic(topic).daily_challenges.maximum(:score) || 0
  end
end
