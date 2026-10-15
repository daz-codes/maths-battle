class FactStat < ApplicationRecord
  belongs_to :user

  # Adds each answer in an attempt to the user's running totals for that fact
  def self.record(attempt)
    topic = attempt.topic_module

    attempt.results.group_by { |r| topic.fact_key(r["a"], r["b"]) }.each do |fact, answers|
      stat = attempt.user.fact_stats.find_or_initialize_by(topic: attempt.topic, fact: fact)
      wrong = answers.count { |r| !r["correct"] }
      stat.correct_count += answers.size - wrong
      stat.wrong_count += wrong
      stat.last_wrong_at = attempt.created_at if wrong.positive?
      stat.save!
    end
  end
end
