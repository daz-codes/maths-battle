# Saves an attempt from the answers the browser sent. The score is worked out here rather than trusted
# from the client, and answers that couldn't have come from a real one-minute test are refused
module Attempt::Recordable
  extend ActiveSupport::Concern

  MAX_ANSWERS = 150
  # The test lasts 60 seconds; allow a little slack for the end-of-test POST
  MAX_TOTAL_MS = 65_000
  # A review has no clock, so only each answer's time is limited
  MAX_REVIEW_ANSWER_MS = 10.minutes.in_milliseconds
  # Every field a result can have in any topic. Each topic checks its own fields strictly
  RESULT_FIELDS = %i[ a b c d e f n type v flip given ms ]
  # Anything the keypad can type, unfinished answers like "0." or "−" included: those are just wrong.
  # Each topic checks a typed answer against this, and anything else can't have come from the game
  TYPED_ANSWER = %r{\A-?[0-9./]{0,12}\z}
  # A game played offline still counts if it reaches the server within this long
  MAX_OFFLINE_AGE = 30.days

  class Invalid < StandardError; end

  included do
    before_create :score_results, :set_played_on, :record_high_score
    # Stars and badges come last, as they look at the streak and any level up
    after_create :update_streak, :record_fact_stats, :check_level_up, :forget_unlocked_levels, :award_stars, :award_badges
  end

  class_methods do
    # Raises Attempt::Invalid when the answers couldn't have come from a real test.
    # A game sent again with the same client id (a retried upload) is only recorded once
    # Mixed games are issued at the highest level. That signed level stays valid if an offline upload
    # arrives after another game has unlocked a new one. A group game is at whatever level its challenge set,
    # unlocked or not, for one of the challenge's players
    def record!(user:, results:, topic: Topic.default.key, level: 1, client_id: nil, played_at: nil, mode: "practice", round: nil)
      if existing = already_recorded(user, client_id)
        return existing
      end

      topic_module, level = topic_named(topic), Integer(level, exception: false)
      mode == "group" ? check_round(user, round, topic_module, level) : check_unlocked(user, topic_module, level)
      raise Invalid, "Only a group game has a round" if round && mode != "group"
      cleaned = clean_results(topic_module, level, results, mode)
      raise Invalid, "Answer at least one question to finish the daily challenge" if mode == "challenge" && cleaned.empty?

      create_for!(user, client_id:, played_at:, topic:, level:, mode:, round:, results: cleaned)
    rescue ActiveRecord::RecordNotUnique
      already_recorded(user, client_id) || raise
    end

    private
      def already_recorded(user, client_id)
        user.attempts.find_by(client_id: client_id) if client_id.present?
      end

      def create_for!(user, client_id:, played_at:, topic:, level:, mode:, round:, results:)
        transaction do
          user.lock!
          played_at = play_time(played_at)
          raise Invalid, "Today's daily challenge is already done" if mode == "challenge" && user.daily_challenge_on(topic_named(topic), played_at.in_time_zone(user.time_zone).to_date)

          user.attempts.create!(topic: topic, level: level, results: results, client_id: client_id.presence, played_at: played_at, mode: mode, round: round)
        end
      end

      def check_round(user, round, topic, level)
        challenge = round&.challenge
        raise Invalid, "That group challenge isn't there any more" unless challenge
        raise Invalid, "Only the group's players can play its challenge" unless challenge.player?(user)
        raise Invalid, "Bad question" unless challenge.topic_module == topic && challenge.level == level
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

      def clean_results(topic, level, results, mode)
        raise Invalid, "Results must be a list" unless results.is_a?(Array)
        raise Invalid, "Too many answers" if results.size > MAX_ANSWERS

        max_ms = mode == "review" ? MAX_REVIEW_ANSWER_MS : MAX_TOTAL_MS
        results.map { |result| clean_result(topic, level, result, max_ms) }.tap { |cleaned| check_total_time(cleaned) unless mode == "review" }
      end

      # The topic checks and scores each answer; the timing check is the same for every topic
      def clean_result(topic, level, result, max_ms)
        raise Invalid, "Bad answer" unless result.is_a?(Hash)

        result = result.stringify_keys
        topic.clean_result(result, level: level).merge("ms" => clean_ms(result["ms"], max_ms))
      end

      def clean_ms(ms, max_ms)
        Integer(ms, exception: false).tap { |value| raise Invalid, "Bad timing" unless value&.between?(0, max_ms) }
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
      best_before =
        if daily_challenge? then user.best_daily_challenge(topic_module)
        elsif review? || group? || mixed? then Float::INFINITY # mistakes, a leaderboard or a mix: no score to beat
        else user.best_score(topic_module, level)
        end
      self.new_high_score = score.positive? && score > best_before
      self.best_score = review? || group? || mixed? ? score : [ score, best_before ].max
    end

    # A snapshot of the streak is kept on the attempt for its results and share pages. Reaching 7 or 30 days
    # can earn a streak freeze
    def update_streak
      grew = daily_challenge? || counted? ? user.refresh_streak! : 0
      update_column(:earned_streak_freeze, true) if grew.positive? && user.earn_streak_freeze(grew)
      update_column(:streak, user.streak)
    end

    # Not a review's answers: with no clock and the questions just got wrong, they'd skew the speed and accuracy
    # that pick a level's questions
    def record_fact_stats
      user.fact_stats.record(self) unless review?
    end

    # The game that unlocks the next level: the level's first bronze, unless the next level was already reached.
    # Only practice
    def check_level_up
      return unless practice? && topic_module.level(level + 1)

      update_column(:levelled_up, true) if first_bronze? && user.attempts.at_level(topic_module, level + 1).none?
    end

    # This game may have unlocked a level, or been the first played at one
    def forget_unlocked_levels
      user.forget_unlocked_levels
    end
end
