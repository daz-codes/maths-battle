# The times tables topic: what its questions and answers are
module TimesTables
  TOPIC = "times_tables"
  FACTORS = 1..12
  # Tables almost everyone finds trivial: asked rarely, and left out of best/worst rankings
  TRIVIAL_FACTORS = [ 1, 10 ]
  # How hard each table usually is for children, 0 (easy) to 2 (hard)
  DIFFICULTY = { 1 => 0, 2 => 0, 5 => 0, 10 => 0, 3 => 1, 4 => 1, 11 => 1, 6 => 2, 7 => 2, 8 => 2, 9 => 2, 12 => 2 }

  # Every fact once, smaller number first: [1, 1], [1, 2] … [12, 12]
  def self.facts
    FACTORS.to_a.repeated_combination(2).to_a
  end

  # 7×8 and 8×7 are the same fact, so the smaller number always comes first
  def self.fact_key(a, b)
    [ a, b ].minmax.join("x")
  end

  # A fact is as hard as its harder table: 2×7 is easy, 7×8 is hard
  def self.difficulty(fact)
    fact.map { |factor| DIFFICULTY.fetch(factor) }.max
  end

  def self.trivial?(fact)
    fact.intersect?(TRIVIAL_FACTORS)
  end

  def self.answer(a, b)
    a * b
  end

  def self.valid_question?(a, b)
    FACTORS.cover?(a) && FACTORS.cover?(b)
  end
end
