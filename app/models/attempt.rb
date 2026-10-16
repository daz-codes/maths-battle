class Attempt < ApplicationRecord
  include Recordable, Reviewable, Shareable

  belongs_to :user

  validates :topic, inclusion: { in: Topic.keys }

  # Games long enough to count: starting a test and walking away doesn't
  scope :counted, -> { where(answered: MIN_ANSWERS_FOR_STREAK..) }
  scope :in_topic, ->(topic, level = nil) { where(topic: topic::TOPIC, **({ level: level } if level).to_h) }
  # Games good enough to count towards levelling up: plenty answered, nearly all right
  scope :good, -> { where(answered: User::Levelable::GOOD_GAME_ANSWERS..).where("score >= answered * ?", User::Levelable::GOOD_GAME_ACCURACY) }

  def topic_module
    Topic.find(topic)
  end

  def level_details
    Topic.level(topic_module, level)
  end

  def good?
    answered >= User::Levelable::GOOD_GAME_ANSWERS && score >= answered * User::Levelable::GOOD_GAME_ACCURACY
  end

  def results_by_fact
    results.group_by { |result| fact_key(result) }
  end

  def mistakes
    results.reject { |result| result["correct"] }
  end

  def perfect?
    answered.positive? && score == answered
  end

  private
    def fact_key(result)
      topic_module.fact_key(result)
    end
end
