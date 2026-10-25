# A player's Daily Tables Test (DailyTest): their one go on a day, in their own time zone
module User::DailyTestable
  extend ActiveSupport::Concern

  def daily_test_on(day = today)
    attempts.find_by(mode: "daily", played_on: day) if persisted?
  end
end
