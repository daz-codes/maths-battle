class Attempt < ApplicationRecord
  include Recordable, Reviewable, Shareable

  TOPICS = { TimesTables::TOPIC => TimesTables }

  belongs_to :user

  validates :topic, inclusion: { in: TOPICS.keys }

  def topic_module
    TOPICS.fetch(topic)
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
      topic_module.fact_key(result["a"], result["b"])
    end
end
