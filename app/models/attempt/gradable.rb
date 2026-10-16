# Which games count, in the database and for one game. A game long enough counts towards the streak
# (starting a test and walking away doesn't); a good one, with plenty answered and nearly all right,
# counts towards levelling up
module Attempt::Gradable
  extend ActiveSupport::Concern

  MIN_ANSWERS_FOR_STREAK = 5
  GOOD_GAME_ANSWERS = 20
  GOOD_GAME_ACCURACY = 0.9

  included do
    scope :counted, -> { where(answered: MIN_ANSWERS_FOR_STREAK..) }
    scope :good, -> { where(answered: GOOD_GAME_ANSWERS..).where("score >= answered * ?", GOOD_GAME_ACCURACY) }
  end

  def counted?
    answered >= MIN_ANSWERS_FOR_STREAK
  end

  def good?
    answered >= GOOD_GAME_ANSWERS && score >= answered * GOOD_GAME_ACCURACY
  end
end
