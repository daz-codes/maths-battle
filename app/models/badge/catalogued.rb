# Every badge there is, in the order they're shown. Score and level badges name their topic rather than using
# its emoji, as the times tables ✖️ would look like a wrong answer. Each kind has a check: a question asked of a game,
# like [:scored?, TimesTables, 25], which earns the badge the first time it's true.
# Badges never name the player, so they're safe to show on a shared result
module Badge::Catalogued
  extend ActiveSupport::Concern

  Kind = Data.define(:key, :group, :emoji, :name, :description, :check)

  GROUPS = { start: "Getting started", scores: "Scores", streaks: "Streaks", levels: "Levels", special: "Special" }
  STREAKS = { 3 => "3 day streak", 7 => "1 week streak", 14 => "2 week streak", 30 => "1 month streak", 100 => "100 day streak" }

  class_methods do
    def catalogue
      @catalogue ||= [ *starting_kinds, *score_kinds, *streak_kinds, *level_kinds, *special_kinds ].freeze
    end

    def keys
      catalogue.map(&:key)
    end

    def kind(key)
      catalogue.find { |kind| kind.key == key }
    end

    def in_group(group)
      catalogue.select { |kind| kind.group == group }
    end

    private
      def starting_kinds
        [
          Kind.new("first_game", :start, "🎉", "First minute", "Finish your first game", [ :counted? ]),
          Kind.new("all_topics", :start, "🌈", "All-rounder", "Play a game of every topic", [ :played_every_topic? ])
        ]
      end

      def score_kinds
        Topic::ALL.flat_map do |topic|
          topic.badge_scores.map do |score|
            Kind.new("score_#{score}_#{topic.key}", :scores, "🎯", "#{score} #{topic.title.downcase} in a minute",
              "Get #{score} right in one game of #{topic.title.downcase}", [ :scored?, topic, score ])
          end
        end
      end

      def streak_kinds
        STREAKS.map do |days, name|
          Kind.new("streak_#{days}", :streaks, "🔥", name, "Play #{days} days in a row", [ :streak_reached?, days ])
        end
      end

      # Level 1 is where everyone starts, so there's a badge for each level after it
      def level_kinds
        Topic::ALL.flat_map do |topic|
          topic.levels.drop(1).map do |level|
            Kind.new("level_#{level[:number]}_#{topic.key}", :levels, "⭐", "#{topic.title} level #{level[:number]}",
              "Unlock #{level[:name]}", [ :reached_level?, topic, level[:number] ])
          end
        end
      end

      def special_kinds
        [
          Kind.new("perfect", :special, "💯", "Perfect game", "Get every answer right, with at least #{Attempt::GOOD_GAME_ANSWERS} answered", [ :perfect_game? ]),
          Kind.new("speedy", :special, "⚡", "Speedy", "Average under 2 seconds an answer, with at least #{Attempt::SPEEDY_GAME_ANSWERS} answered", [ :speedy?, 2_000 ]),
          Kind.new("lightning", :special, "🚀", "Lightning", "Average under 1 second an answer, with at least #{Attempt::SPEEDY_GAME_ANSWERS} answered", [ :speedy?, 1_000 ]),
          Kind.new("comeback", :special, "💪", "Comeback", "Beat your best score after a week or more away", [ :comeback? ])
        ]
      end
  end

  def details
    self.class.kind(kind)
  end

  delegate :emoji, :name, :description, :group, to: :details
end
