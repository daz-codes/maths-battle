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
      stat.save!
    end
  end

  def answered_count
    correct_count + wrong_count
  end

  # 0.0 to 1.0, or nil if the fact hasn't been asked yet
  def fraction_correct
    correct_count.fdiv(answered_count) if answered_count.positive?
  end

  def percent_correct
    (fraction_correct * 100).round if fraction_correct
  end
end
