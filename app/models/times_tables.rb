module TimesTables
  TOPIC = "times_tables"
  FACTORS = 1..12

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

  def self.questions_for(user)
    QuestionGenerator.new(user).questions
  end
end
