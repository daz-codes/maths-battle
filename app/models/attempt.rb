class Attempt < ApplicationRecord
  include Badgeable, Gradable, Recordable, Reviewable, Shareable

  belongs_to :user

  validates :topic, inclusion: { in: Topic.keys }

  scope :in_topic, ->(topic) { where(topic: topic.key) }
  scope :at_level, ->(topic, level) { in_topic(topic).where(level: level) }

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
