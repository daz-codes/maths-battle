# The Daily Challenge: today's Daily Tables Test and Patternz, and for each one played, where the player stands
# among everyone today
class DailyChallengeController < ApplicationController
  allow_unauthenticated_access

  def show
    @user = current_player
    @daily_tests = DailyTest.on(@user.today)
  end
end
