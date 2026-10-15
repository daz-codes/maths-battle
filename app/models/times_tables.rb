# The times tables topic: what its questions and answers are
module TimesTables
  TOPIC = "times_tables"
  FACTORS = 1..12

  # Every fact once, smaller number first: [1, 1], [1, 2] … [12, 12]
  def self.facts
    FACTORS.to_a.repeated_combination(2).to_a
  end

  # 7×8 and 8×7 are the same fact, so the smaller number always comes first
  def self.fact_key(a, b)
    [ a, b ].minmax.join("x")
  end

  def self.answer(a, b)
    a * b
  end

  def self.valid_question?(a, b)
    FACTORS.cover?(a) && FACTORS.cover?(b)
  end
end
