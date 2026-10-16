class Attempt < ApplicationRecord
  include Recordable, Reviewable, Shareable

  belongs_to :user

  validates :topic, inclusion: { in: Topic.keys }

  # Games long enough to count: starting a test and walking away doesn't
  scope :counted, -> { where(answered: MIN_ANSWERS_FOR_STREAK..) }
  scope :in_topic, ->(topic) { where(topic: topic::TOPIC) }

  def topic_module
    Topic.find(topic)
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
