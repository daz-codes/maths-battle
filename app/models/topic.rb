# Every topic that can be played. Each one is a module answering the same questions (see TimesTables)
module Topic
  ALL = [ TimesTables, Equations, Functions, SimultaneousEquations ]

  def self.default
    TimesTables
  end

  def self.find(key)
    ALL.find { |topic| topic.key == key }
  end

  def self.find_by_slug(slug)
    ALL.find { |topic| topic.slug == slug }
  end

  def self.keys
    ALL.map(&:key)
  end
end
