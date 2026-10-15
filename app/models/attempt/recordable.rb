# Saves an attempt from the answers the browser sent. The score is worked out here rather than trusted
# from the client, and answers that couldn't have come from a real one-minute test are refused
module Attempt::Recordable
  extend ActiveSupport::Concern

  MAX_ANSWERS = 150
  MIN_ANSWERS_FOR_STREAK = 5
  # The test lasts 60 seconds; allow a little slack for the end-of-test POST
  MAX_TOTAL_MS = 65_000
  MAX_ANSWER = 999

  class Invalid < StandardError; end

  included do
    before_create :score_results, :update_player
    after_create :record_fact_stats
  end

  class_methods do
    # Raises Attempt::Invalid when the answers couldn't have come from a real test
    def record!(user:, results:, topic: TimesTables::TOPIC)
      results = clean_results(topic_named(topic), results)

      transaction do
        user.lock!
        user.attempts.create!(topic: topic, results: results)
      end
    end

    private
      def topic_named(topic)
        Attempt::TOPICS.fetch(topic) { raise Invalid, "Unknown topic" }
      end

      def clean_results(topic, results)
        raise Invalid, "Results must be a list" unless results.is_a?(Array)
        raise Invalid, "Too many answers" if results.size > MAX_ANSWERS

        results.map { |result| clean_result(topic, result) }.tap { |cleaned| check_total_time(cleaned) }
      end

      def clean_result(topic, result)
        a, b, given, ms = numbers_in(result)
        check_result(topic, a, b, given, ms)

        { "a" => a, "b" => b, "given" => given, "correct" => given == topic.answer(a, b), "ms" => ms }
      end

      def numbers_in(result)
        raise Invalid, "Bad answer" unless result.is_a?(Hash)

        result.stringify_keys.values_at("a", "b", "given", "ms").map { |value| Integer(value, exception: false) }
      end

      def check_result(topic, a, b, given, ms)
        raise Invalid, "Bad question" unless a && b && topic.valid_question?(a, b)
        raise Invalid, "Bad answer" unless given&.between?(0, MAX_ANSWER)
        raise Invalid, "Bad timing" unless ms&.between?(0, MAX_TOTAL_MS)
      end

      def check_total_time(results)
        raise Invalid, "Bad timing" if results.sum { |result| result["ms"] } > MAX_TOTAL_MS
      end
  end

  private
    def score_results
      self.score = results.count { |result| result["correct"] }
      self.answered = results.size
    end

    # Best score and streak, with a snapshot of the streak kept on the attempt for its results and share pages
    def update_player
      self.new_high_score = user.record_score!(score)
      user.record_practice! if counts_toward_streak?
      self.streak = user.streak
    end

    # Starting a test and walking away doesn't count
    def counts_toward_streak?
      answered >= MIN_ANSWERS_FOR_STREAK
    end

    def record_fact_stats
      user.fact_stats.record(self)
    end
end
