# Which games count. A game long enough counts towards average scores and badges (starting a test and walking
# away doesn't), and counted towards the streak before only daily challenges did (User::Streakable). A perfect
# one needs a proper number of answers too
module Attempt::Gradable
  extend ActiveSupport::Concern

  MIN_ANSWERS_FOR_STREAK = 5
  PERFECT_GAME_ANSWERS = 10

  included do
    scope :counted, -> { where(answered: MIN_ANSWERS_FOR_STREAK..) }
  end

  def counted?
    answered >= MIN_ANSWERS_FOR_STREAK
  end
end
