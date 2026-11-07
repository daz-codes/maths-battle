# Every award there is, in the order they're shown. Each kind has a check, a question asked of a game, like
# [:right_at_least?, 20], which earns it the first time it's true; a kind with no check is given when something
# happens (Badge.award). Awards never name the player
module Badge::Catalogued
  extend ActiveSupport::Concern

  Kind = Data.define(:key, :group, :icon, :name, :description, :check)

  GROUPS = { start: "Getting started", streaks: "Answer streaks", right: "Right answers", scores: "Scores", power_ups: "Power-ups", special: "Special" }
  STREAKS = [ 5, 10, 20, 30, 50 ]
  RIGHT = [ 10, 20, 30, 40, 50 ]
  SCORES = [ 500, 1_000, 2_500, 5_000, 10_000 ]
  POWER_UPS = {
    "double" => [ "Double trouble", "Claim Double points" ], "shield" => [ "Shielded", "Claim a Streak shield" ],
    "time" => [ "Extra time", "Claim Extra time" ], "freeze" => [ "Ice cold", "Freeze everyone in a battle" ],
    "scramble" => [ "Scrambler", "Scramble everyone's keys in a battle" ], "reset" => [ "Streak breaker", "Break everyone's streaks in a battle" ]
  }
  # The world league needs this many players today before its top ten means something
  TOP_TEN_FROM = 20

  class_methods do
    def catalogue
      @catalogue ||= [ *starting_kinds, *streak_kinds, *right_kinds, *score_kinds, *power_up_kinds, *special_kinds ].freeze
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
          Kind.new("first_game", :start, :party, "First minute", "Finish your first game", [ :finished? ]),
          Kind.new("first_battle", :start, :versus, "Into battle", "Finish a battle against other players", [ :battle_finished? ]),
          Kind.new("first_win", :start, :trophy, "Victory!", "Come first in a battle", nil),
          Kind.new("first_power_up", :start, :lightning, "Powered up", "Claim your first power-up", [ :claimed_power_up? ]),
          Kind.new("team_player", :start, :people, "Team player", "Join or make a league", nil)
        ]
      end

      def streak_kinds
        STREAKS.map { |streak| Kind.new("streak_#{streak}", :streaks, :flame, "#{streak} in a row", "Get #{streak} right in a row in one game", [ :streak_at_least?, streak ]) }
      end

      def right_kinds
        RIGHT.map { |right| Kind.new("right_#{right}", :right, :target, "#{right} right", "Get #{right} right in one game", [ :right_at_least?, right ]) }
      end

      def score_kinds
        SCORES.map { |score| Kind.new("score_#{score}", :scores, :star, "#{score.to_fs(:delimited)} points", "Score #{score.to_fs(:delimited)} in one game", [ :scored_at_least?, score ]) }
      end

      def power_up_kinds
        POWER_UPS.map do |power_up, (name, description)|
          Kind.new("power_#{power_up}", :power_ups, GamesHelper::POWER_UP_ICONS.fetch(power_up), name, description, [ :claimed?, power_up ])
        end
      end

      def special_kinds
        [
          Kind.new("perfect", :special, :perfect, "Perfect game", "Get every answer right, with at least #{Attempt::Badgeable::PERFECT_ANSWERS} answered", [ :perfect_game? ]),
          Kind.new("expert", :special, :rocket, "Expert", "Answer quickly enough to reach the hardest questions", [ :reached_the_top? ]),
          Kind.new("top_ten", :special, :rainbow, "Top ten", "Be in the world league's top ten, on a day at least #{TOP_TEN_FROM} play", [ :in_the_top_ten? ])
        ]
      end
  end

  def details
    self.class.kind(kind)
  end

  delegate :icon, :name, :description, :group, to: :details
end
