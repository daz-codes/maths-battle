# Saves an attempt from the answers the browser sent. The score is worked out here rather than trusted
# from the client, and answers that couldn't have come from a real one-minute test are refused
module Attempt::Recordable
  extend ActiveSupport::Concern

  MAX_ANSWERS = 150
  MIN_ANSWERS_FOR_STREAK = 5
  # The test lasts 60 seconds; allow a little slack for the end-of-test POST
  MAX_TOTAL_MS = 65_000
  # Every field a result can have in any topic. Each topic checks its own fields strictly
  RESULT_FIELDS = %i[ a b c type v flip given ms ]
  # A game played offline still counts if it reaches the server within this long
  MAX_OFFLINE_AGE = 30.days

  class Invalid < StandardError; end

  included do
    before_create :score_results, :set_played_on, :record_high_score
    after_create :update_streak, :record_fact_stats
  end

  class_methods do
    # Raises Attempt::Invalid when the answers couldn't have come from a real test.
    # A game sent again with the same client id (a retried upload) is only recorded once
    def record!(user:, results:, topic: Topic.default::TOPIC, client_id: nil, played_at: nil)
      already_recorded(user, client_id) || create_for!(user, client_id:, played_at:, topic:, results: clean_results(topic_named(topic), results))
    rescue ActiveRecord::RecordNotUnique
      already_recorded(user, client_id) || raise
    end

    private
      def already_recorded(user, client_id)
        user.attempts.find_by(client_id: client_id) if client_id.present?
      end

      def create_for!(user, client_id:, played_at:, topic:, results:)
        transaction do
          user.lock!
          user.attempts.create!(topic: topic, results: results, client_id: client_id.presence, played_at: play_time(played_at))
        end
      end

      # The device's clock can be wrong, so a time in the future, or too long ago, counts as now
      def play_time(value)
        time = Time.zone.parse(value.to_s) if value.present?
        time&.between?(MAX_OFFLINE_AGE.ago, 5.minutes.from_now) ? time : Time.current
      rescue ArgumentError
        Time.current
      end

      def topic_named(topic)
        Topic.find(topic) || raise(Invalid, "Unknown topic")
      end

      def clean_results(topic, results)
        raise Invalid, "Results must be a list" unless results.is_a?(Array)
        raise Invalid, "Too many answers" if results.size > MAX_ANSWERS

        results.map { |result| clean_result(topic, result) }.tap { |cleaned| check_total_time(cleaned) }
      end

      # The topic checks and scores each answer; the timing check is the same for every topic
      def clean_result(topic, result)
        raise Invalid, "Bad answer" unless result.is_a?(Hash)

        result = result.stringify_keys
        topic.clean_result(result).merge("ms" => clean_ms(result["ms"]))
      end

      def clean_ms(ms)
        Integer(ms, exception: false).tap { |value| raise Invalid, "Bad timing" unless value&.between?(0, MAX_TOTAL_MS) }
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

    # The day the game counts towards, in the player's time zone
    def set_played_on
      self.played_at ||= Time.current
      self.played_on = played_at.in_time_zone(user.time_zone).to_date
    end

    # Best in this topic: a good times tables score shouldn't make equations look bad
    def record_high_score
      self.new_high_score = score.positive? && score > user.best_score(topic_module)
    end

    # A snapshot of the streak is kept on the attempt for its results and share pages
    def update_streak
      user.refresh_streak! if counts_toward_streak?
      update_column(:streak, user.streak)
    end

    # Starting a test and walking away doesn't count
    def counts_toward_streak?
      answered >= MIN_ANSWERS_FOR_STREAK
    end

    def record_fact_stats
      user.fact_stats.record(self)
    end
end
