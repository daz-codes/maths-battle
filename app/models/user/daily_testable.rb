# A player's daily challenges (DailyTest): their one go at each kind on a day, in their own time zone, and how
# they've done in every one of a kind: their best and average scores, and how many they've played
module User::DailyTestable
  extend ActiveSupport::Concern

  def daily_game(test)
    daily_games(test.kind).find_by(played_on: test.day) if persisted?
  end

  def daily_games(kind)
    attempts.where(mode: "daily", topic: DailyTest::KINDS.fetch(kind)[:topic].key)
  end

  def best_daily_game(kind)
    daily_games(kind).maximum(:score) || 0
  end

  def average_daily_game(kind)
    daily_games(kind).average(:score)&.round
  end
end
