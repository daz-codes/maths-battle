# Which games count. A game long enough counts towards the streak (starting a test and walking away doesn't),
# and a perfect one needs a proper number of answers too
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
