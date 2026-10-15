class Attempt < ApplicationRecord
  TOPICS = { TimesTables::TOPIC => TimesTables }
  MAX_ANSWERS = 150
  MIN_ANSWERS_FOR_STREAK = 5
  # The test lasts 60 seconds; allow a little slack for the end-of-test POST
  MAX_TOTAL_MS = 65_000
  MAX_ANSWER = 999

  class Invalid < StandardError; end

  belongs_to :user
  has_secure_token :share_token

  validates :topic, inclusion: { in: TOPICS.keys }

  # Saves an attempt from the answers the browser sent, scoring it here rather than trusting the client.
  # Raises Attempt::Invalid when the answers couldn't have come from a real test
  def self.record!(user:, results:, topic: TimesTables::TOPIC)
    raise Invalid, "Unknown topic" unless TOPICS.key?(topic)
    results = score_results(TOPICS[topic], results)

    transaction do
      user.lock!
      score = results.count { |r| r["correct"] }

      new_high_score = user.record_score!(score)
      user.record_practice! if results.size >= MIN_ANSWERS_FOR_STREAK

      attempt = user.attempts.create!(topic: topic, results: results, score: score, answered: results.size,
        new_high_score: new_high_score, streak: user.streak)
      FactStat.record(attempt)
      attempt
    end
  end

  def self.score_results(topic, raw)
    raise Invalid, "Results must be a list" unless raw.is_a?(Array)
    raise Invalid, "Too many answers" if raw.size > MAX_ANSWERS

    results = raw.map do |r|
      raise Invalid, "Bad answer" unless r.is_a?(Hash)
      r = r.stringify_keys
      a, b, given, ms = r.values_at("a", "b", "given", "ms").map { |v| Integer(v, exception: false) }
      raise Invalid, "Bad question" unless a && b && topic.valid_question?(a, b)
      raise Invalid, "Bad answer" unless given&.between?(0, MAX_ANSWER)
      raise Invalid, "Bad timing" unless ms&.between?(0, MAX_TOTAL_MS)

      { "a" => a, "b" => b, "given" => given, "correct" => given == topic.answer(a, b), "ms" => ms }
    end

    raise Invalid, "Bad timing" if results.sum { |r| r["ms"] } > MAX_TOTAL_MS
    results
  end

  def topic_module
    TOPICS.fetch(topic)
  end

  def mistakes
    results.reject { |r| r["correct"] }
  end

  def perfect?
    answered.positive? && score == answered
  end
end
