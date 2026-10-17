# A day a streak freeze covered, so the streak went on through it (User::StreakFreezable)
class FrozenDay < ApplicationRecord
  belongs_to :user
end
