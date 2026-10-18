# Medals, for topics that play by them (times tables): a level's practice game earns bronze, silver or gold
# for its score, the level keeps the best medal its games have earned, and the first bronze unlocks the next
# level. A daily challenge mixes levels, so it earns no medal
module Attempt::Medallable
  extend ActiveSupport::Concern

  MEDAL_EMOJI = { gold: "🥇", silver: "🥈", bronze: "🥉" }
  MEDAL_NAMES = { gold: "Gold", silver: "Silver", bronze: "Bronze" }

  class_methods do
    # The best medal a score earns in a topic, or nil
    def medal_for(score, topic)
      topic.medals&.find { |_, needed| score >= needed }&.first
    end

    def medal_rank(medal)
      medal ? MEDAL_EMOJI.keys.reverse.index(medal) + 1 : 0
    end
  end

  def medal
    self.class.medal_for(score, topic_module) unless daily_challenge
  end

  # This game's medal, if it's better than any the level had before
  def new_medal
    medal if self.class.medal_rank(medal) > self.class.medal_rank(self.class.medal_for(best_before_this, topic_module))
  end

  private
    # The first bronze at a level unlocks the next one
    def first_bronze?
      topic_module.medals? && !daily_challenge && score >= topic_module.medals[:bronze] && best_before_this < topic_module.medals[:bronze]
    end

    # The level's best from the games recorded before this one
    def best_before_this
      user.attempts.at_level(topic_module, level).where(id: ...id).maximum(:score).to_i
    end
end
