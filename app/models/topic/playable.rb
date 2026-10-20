# What every topic has, read from its constants: TimesTables and Equations each extend this, so the rest
# of the app asks a topic for its slug or a level rather than reaching into its constants
module Topic::Playable
  # As stored with each game and fact: "times_tables"
  def key
    self::TOPIC
  end

  # As in URLs: "times-tables"
  def slug
    self::SLUG
  end

  # "Times tables". Not name, which every module already has
  def title
    self::NAME
  end

  def emoji
    self::EMOJI
  end

  def levels
    self::LEVELS
  end

  def level(number)
    levels.find { |level| level[:number] == number }
  end

  def max_level
    levels.size
  end

  # Practice asks the current level's facts. Mixed games and reviews can also ask any earlier level's.
  def levels_through(number)
    raise Attempt::Invalid, "Unknown level" unless level(number)

    levels.take_while { |details| details[:number] <= number }
  end

  def facts_through(number)
    levels_through(number).flat_map { |details| facts(details[:number]) }.uniq
  end

  # What one pick of a fact asks: one question, unless a topic asks several about the same thing
  # (simultaneous equations asks for y, then x)
  def questions_for(fact, level:, random:)
    [ question(fact, level: level, random: random) ]
  end

  # Under how many ms a right answer earns the quick and lightning stars
  def star_times
    self::STAR_TIMES
  end

  # A level's tutorial, if the topic has them: steps to tap through, then one to try (see TimesTables::Lessons)
  def lesson(number)
    self::Lessons::ALL[number] if const_defined?(:Lessons, false)
  end

  # The scores for bronze, silver and gold: a level's practice earns a medal, and the first bronze unlocks the
  # next level (Attempt::Medallable). Each topic sets its own, as some questions take longer
  def medals
    self::MEDALS
  end

  def badge_scores
    self::BADGE_SCORES
  end
end
