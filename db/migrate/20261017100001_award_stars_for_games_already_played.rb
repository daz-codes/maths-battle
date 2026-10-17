# Existing players get the stars their games so far have earned. Uses the models, as the rules live there;
# on a fresh database there are no games, so it does nothing
class AwardStarsForGamesAlreadyPlayed < ActiveRecord::Migration[8.1]
  def up
    Attempt.reset_column_information
    Attempt.find_each { |attempt| attempt.update_column(:stars, attempt.count_stars) if attempt.topic_module }
  end

  def down
    execute "UPDATE attempts SET stars = 0"
  end
end
