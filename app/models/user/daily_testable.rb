# A player's daily challenges (DailyTest): their games at each kind on a day, in their own time zone, as many as they
# like, and how they've done in every one of a kind: their best and average scores, and how many they've played
module User::DailyTestable
  extend ActiveSupport::Concern

  # Their best game at it that day, the first if they've scored the same twice
  def daily_game(test)
    daily_games_on(test).order(score: :desc, id: :asc).first if persisted?
  end

  def daily_games_on(test)
    daily_games(test.kind).where(played_on: test.day)
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
