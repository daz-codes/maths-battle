# The Challenge: today's Daily Tables Test, and once it's played, where the player stands among everyone today
class DailyChallengeController < ApplicationController
  allow_unauthenticated_access

  def show
    @user = current_player
    @daily_test = DailyTest.new(@user.today)
    @attempt = @user.daily_test_on(@daily_test.day)
  end
end
