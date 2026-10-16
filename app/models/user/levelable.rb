# Topics can have levels (times tables: tables 2–5, 2–12, zeroes, decimals, negatives). A level unlocks after
# enough good games at the one before. Unlocked levels can always be played again, and Play defaults to the highest
module User::Levelable
  extend ActiveSupport::Concern

  GOOD_GAMES_TO_LEVEL_UP = 3

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

  # How many more good games at the highest level until the next one unlocks
  def good_games_to_level_up(topic)
    [ GOOD_GAMES_TO_LEVEL_UP - good_games(topic, unlocked_level(topic)), 0 ].max
  end

  def good_games(topic, level)
    attempts.at_level(topic, level).good.count
  end

  private
    def unlocked?(topic, number)
      attempts.at_level(topic, number).exists? || good_games(topic, number - 1) >= GOOD_GAMES_TO_LEVEL_UP
    end
end
