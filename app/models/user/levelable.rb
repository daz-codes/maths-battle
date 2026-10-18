# Topics have levels (times tables: tables 2–5, 2–12, zeroes, decimals, negatives). A level unlocks with a
# bronze medal at the one before (Attempt::Medallable). Unlocked levels can always be played again, and Play defaults to the highest
module User::Levelable
  extend ActiveSupport::Concern

  # The highest level unlocked: level 1, then each level after one with enough good games (or already played).
  # A page asks this many times, so it's worked out once, and again after a new game or a reload
  def unlocked_level(topic)
    (@unlocked_level ||= {})[topic] ||= topic.levels.map { |level| level[:number] }.take_while { |number| number == 1 || unlocked?(topic, number) }.last
  end

  def forget_unlocked_levels
    @unlocked_level = nil
  end

  def reload(...)
    forget_unlocked_levels
    super
  end

  def unlocked_levels(topic)
    topic.levels.first(unlocked_level(topic))
  end

  def next_level(topic)
    topic.level(unlocked_level(topic) + 1)
  end

  # The best medal a level's games have earned, or nil
  def medal(topic, level)
    Attempt.medal_for(best_score(topic, level), topic)
  end

  private
    def unlocked?(topic, number)
      attempts.at_level(topic, number).exists? || medal(topic, number - 1).present?
    end
end
