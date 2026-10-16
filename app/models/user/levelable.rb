# Topics can have levels (times tables: tables 2–5, 2–12, zeroes, decimals, negatives). A level unlocks after
# enough good games at the one before. Unlocked levels can always be played again, and Play defaults to the highest
module User::Levelable
  GOOD_GAME_ANSWERS = 20
  GOOD_GAME_ACCURACY = 0.9
  GOOD_GAMES_TO_LEVEL_UP = 5

  # The highest level unlocked: level 1, then each level after one with enough good games (or already played)
  def unlocked_level(topic)
    topic.levels.map { |level| level[:number] }.take_while { |number| number == 1 || unlocked?(topic, number) }.last
  end

  def unlocked_levels(topic)
    topic.levels.first(unlocked_level(topic))
  end

  def next_level(topic)
    Topic.level(topic, unlocked_level(topic) + 1)
  end

  # How many more good games at the highest level until the next one unlocks
  def good_games_to_level_up(topic)
    [ GOOD_GAMES_TO_LEVEL_UP - good_games(topic, unlocked_level(topic)), 0 ].max
  end

  def good_games(topic, level)
    attempts.in_topic(topic, level).good.count
  end

  private
    def unlocked?(topic, number)
      attempts.in_topic(topic, number).exists? || good_games(topic, number - 1) >= GOOD_GAMES_TO_LEVEL_UP
    end
end
