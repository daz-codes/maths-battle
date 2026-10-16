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
end
