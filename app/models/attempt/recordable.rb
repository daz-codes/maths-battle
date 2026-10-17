# Saves an attempt from the answers the browser sent. The score is worked out here rather than trusted
# from the client, and answers that couldn't have come from a real one-minute test are refused
module Attempt::Recordable
  extend ActiveSupport::Concern

  MAX_ANSWERS = 150
  # The test lasts 60 seconds; allow a little slack for the end-of-test POST
  MAX_TOTAL_MS = 65_000
  # Every field a result can have in any topic. Each topic checks its own fields strictly
  RESULT_FIELDS = %i[ a b c d e f n type v flip given ms ]
  # A game played offline still counts if it reaches the server within this long
  MAX_OFFLINE_AGE = 30.days

  class Invalid < StandardError; end

  included do
    before_create :score_results, :set_played_on, :record_high_score
    # Badges come last, as they look at the streak and any level up
    after_create :update_streak, :record_fact_stats, :check_level_up, :forget_unlocked_levels, :award_badges
  end

  class_methods do
    # Raises Attempt::Invalid when the answers couldn't have come from a real test.
    # A game sent again with the same client id (a retried upload) is only recorded once
    def record!(user:, results:, topic: Topic.default.key, level: 1, client_id: nil, played_at: nil)
      topic_module, level = topic_named(topic), Integer(level, exception: false)
      check_unlocked(user, topic_module, level)

      already_recorded(user, client_id) ||
        create_for!(user, client_id:, played_at:, topic:, level:, results: clean_results(topic_module, level, results))
    rescue ActiveRecord::RecordNotUnique
      already_recorded(user, client_id) || raise
    end

    private
      def already_recorded(user, client_id)
        user.attempts.find_by(client_id: client_id) if client_id.present?
      end

      def create_for!(user, client_id:, played_at:, topic:, level:, results:)
        transaction do
          user.lock!
          user.attempts.create!(topic: topic, level: level, results: results, client_id: client_id.presence, played_at: play_time(played_at))
        end
      end

      def check_unlocked(user, topic, level)
        raise Invalid, "Level not unlocked" unless level&.between?(1, user.unlocked_level(topic))
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

      def clean_results(topic, level, results)
        raise Invalid, "Results must be a list" unless results.is_a?(Array)
        raise Invalid, "Too many answers" if results.size > MAX_ANSWERS

        results.map { |result| clean_result(topic, level, result) }.tap { |cleaned| check_total_time(cleaned) }
      end

      # The topic checks and scores each answer; the timing check is the same for every topic
      def clean_result(topic, level, result)
        raise Invalid, "Bad answer" unless result.is_a?(Hash)

        result = result.stringify_keys
        topic.clean_result(result, level: level).merge("ms" => clean_ms(result["ms"]))
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

    # Best in this topic and level: a good times tables score shouldn't make equations look bad.
    # Kept on the attempt as it stood then, like the streak, so a shared result doesn't change later
    def record_high_score
      best_before = user.best_score(topic_module, level)
      self.new_high_score = score.positive? && score > best_before
      self.best_score = [ score, best_before ].max
    end

    # A snapshot of the streak is kept on the attempt for its results and share pages
    def update_streak
      user.refresh_streak! if counted?
      update_column(:streak, user.streak)
    end

    def record_fact_stats
      user.fact_stats.record(self)
    end

    # The good game that brings the count to what's needed unlocks the next level
    def check_level_up
      levelled_up = good? && user.good_games(topic_module, level) == User::Levelable::GOOD_GAMES_TO_LEVEL_UP && topic_module.level(level + 1)
      update_column(:levelled_up, true) if levelled_up
    end

    # This game may have unlocked a level, or been the first played at one
    def forget_unlocked_levels
      user.forget_unlocked_levels
    end
end
