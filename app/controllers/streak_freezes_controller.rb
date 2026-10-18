# Buying a streak freeze with stars, from the settings page
class StreakFreezesController < ApplicationController
  def create
    Current.user.buy_streak_freeze!
    redirect_to edit_profile_path, notice: "🧊 You bought a streak freeze. It'll keep your streak going if you miss a day."
  rescue User::StreakFreezable::NotAllowed
    redirect_to edit_profile_path, alert: "You can't buy a streak freeze right now."
  end
end
