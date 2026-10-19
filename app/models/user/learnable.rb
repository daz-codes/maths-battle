# Lessons a player has finished, once a day for each; another go the same day changes nothing.
# Lessons used to keep the streak going, and the days they did still count (User::Streakable)
module User::Learnable
  extend ActiveSupport::Concern

  included do
    has_many :lesson_completions, dependent: :destroy
  end

  def complete_lesson!(topic, level)
    lesson_completions.find_or_create_by!(topic: topic.key, level: level, completed_on: today)
  end
end
