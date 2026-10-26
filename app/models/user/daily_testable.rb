# A player's Daily Tables Test (DailyTest): their one go on a day, in their own time zone, and how they've done in
# them all: their best and average scores, and how many they've played
module User::DailyTestable
  extend ActiveSupport::Concern

  def daily_test_on(day = today)
    daily_tests.find_by(played_on: day) if persisted?
  end

  def daily_tests
    attempts.where(mode: "daily")
  end

  def best_daily_test
    daily_tests.maximum(:score) || 0
  end

  def average_daily_test
    daily_tests.average(:score)&.round
  end
end
