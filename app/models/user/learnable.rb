# Lessons a player has finished. Finishing one counts towards the streak for the day, like a game
module User::Learnable
  extend ActiveSupport::Concern

  included do
    has_many :lesson_completions, dependent: :destroy
  end

  # Once a day for each lesson counts; another go the same day changes nothing. Returns the streak, kept for today
  def complete_lesson!(topic, level)
    with_lock do
      lesson_completions.find_or_create_by!(topic: topic.key, level: level, completed_on: today)
      grew = refresh_streak!
      earn_streak_freeze(grew) if grew.positive?
    end
    streak
  end
end
