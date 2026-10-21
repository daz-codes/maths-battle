# Which games count. Any game finished with an answer keeps the streak going (User::Streakable); a game long
# enough counts towards average scores and badges (starting a test and walking away doesn't). A perfect one needs
# a proper number of answers too
module Attempt::Gradable
  extend ActiveSupport::Concern

  MIN_ANSWERS_COUNTED = 5
  PERFECT_GAME_ANSWERS = 10

  included do
    scope :finished, -> { where(answered: 1..) }
    scope :counted, -> { where(answered: MIN_ANSWERS_COUNTED..) }
  end

  def finished?
    answered.positive?
  end

  def counted?
    answered >= MIN_ANSWERS_COUNTED
  end
end
