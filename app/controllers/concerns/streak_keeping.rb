# Coming back after missing days uses up streak freezes to cover them, before any page shows the streak
module StreakKeeping
  extend ActiveSupport::Concern

  included do
    before_action :keep_streak, if: -> { request.get? && request.format.html? }
  end

  private
    def keep_streak
      return unless authenticated? && (used = Current.user.use_streak_freezes!).positive?

      flash.now[:notice] = "🧊 #{used == 1 ? "A streak freeze" : "#{used} streak freezes"} kept your #{Current.user.streak} day streak going!"
    end
end
