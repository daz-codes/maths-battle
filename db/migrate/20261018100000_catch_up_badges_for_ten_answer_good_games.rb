# A good game (and a perfect one) now needs 10 answers rather than 20, so earlier perfect games of 10 to 19
# answers have earned that badge. Catching up only adds badges that are missing
class CatchUpBadgesForTenAnswerGoodGames < ActiveRecord::Migration[8.1]
  def up
    User.find_each(&:catch_up_badges!)
  end

  def down
  end
end
