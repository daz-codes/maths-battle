# Every topic that can be played. Each one is a module answering the same questions (see TimesTables)
module Topic
  ALL = [ TimesTables, Equations ]

  def self.default
    TimesTables
  end

  def self.find(key)
    ALL.find { |topic| topic::TOPIC == key }
  end

  def self.find_by_slug(slug)
    ALL.find { |topic| topic::SLUG == slug }
  end

  def self.keys
    ALL.map { |topic| topic::TOPIC }
  end

  def self.level(topic, number)
    topic.levels.find { |level| level[:number] == number }
  end

  def self.max_level(topic)
    topic.levels.size
  end
end
