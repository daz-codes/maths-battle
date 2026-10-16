class FactStat < ApplicationRecord
  include Timeable

  belongs_to :user

  # Adds each answer in an attempt to the player's running totals for that fact
  def self.record(attempt)
    attempt.results_by_fact.each do |fact, answers|
      find_or_initialize_by(topic: attempt.topic, level: attempt.level, fact: fact).add(answers)
    end
  end

  def add(answers)
    right = answers.select { |answer| answer["correct"] }

    self.correct_count += right.size
    self.wrong_count += answers.size - right.size
    self.correct_ms += self.class.total_counted_ms(right)
    save!
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
