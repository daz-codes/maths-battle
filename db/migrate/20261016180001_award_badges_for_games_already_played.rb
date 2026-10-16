# Existing players get the badges their games so far have earned, as if they'd had them all along.
# Uses the models, as the rules live there; on a fresh database there are no players, so it does nothing
class AwardBadgesForGamesAlreadyPlayed < ActiveRecord::Migration[8.1]
  def up
    User.reset_column_information
    Attempt.reset_column_information
    User.find_each(&:catch_up_badges!)
  end

  def down
    execute "DELETE FROM badges"
  end
end
