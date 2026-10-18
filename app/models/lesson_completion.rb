# A lesson finished on a day: it keeps the streak going for that day, like a game (User::Streakable)
class LessonCompletion < ApplicationRecord
  belongs_to :user

  validates :topic, inclusion: { in: Topic.keys }
end
