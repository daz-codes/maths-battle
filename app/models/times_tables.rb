# The times tables topic: what its questions are, how answers are checked, and how it's grouped (by table).
# Every topic answers the same questions, so the game, scoring, stats and feedback work for any of them.
#
# It has levels. Each question rests on a table fact like 7 × 3; higher levels move its numbers by powers of ten
# (Topic::Tabled), first with zeroes (70 × 300), then decimals (0.7 × 3), then both (0.7 × 3000)
module TimesTables
  include Topic::Tabled

  TOPIC = "times_tables"
  SLUG = "times-tables"
  NAME = "Times tables"
  EMOJI = "✖️"
  LEVELS = [
    { number: 1, name: "Tables 2–5", example: "4 × 3" },
    { number: 2, name: "Tables 2–12", example: "7 × 8" },
    { number: 3, name: "Zeroes", example: "40 × 300" },
    { number: 4, name: "Decimals", example: "0.7 × 3" },
    { number: 5, name: "Zeroes and decimals", example: "0.7 × 3000" }
  ]
  # A level's practice earns a medal for its score; bronze unlocks the next level
  MEDALS = { gold: 20, silver: 10, bronze: 5 }
  # A right answer under 1 second earns the lightning stars, under 2 the quick ones
  STAR_TIMES = { lightning: 1_000, quick: 2_000 }
  # Scores in one game that earn a badge
  BADGE_SCORES = [ 5, 10, 25, 50, 75, 100 ]

  extend Topic::Playable
  extend self

  # The table fact under a question: 0.7 × 3000 is 7 × 3
  def fact_key(result)
    fact_of(*[ result["a"], result["b"] ].map { |number| decimal(number) })
  end

  # Questions

  # Asked either way round: 7 × 8 or 8 × 7, moved for the level: 70 × 8, 0.7 × 3000
  def question(fact, level: 1, random:)
    worked(scaled_factors(fact, level, random).then { |a, b| { a: a, b: b } })
  end

  # The answers the browser sent, checked and scored here rather than trusted. The fact must be one the level
  # asks, so level 1 only takes the 2–5 tables
  def clean_result(result, level: 1)
    a, b = result.values_at("a", "b").map { |number| decimal(number) }
    raise Attempt::Invalid, "Bad question" unless [ a, b ].all? { |number| number && allowed?(number, level) }
    raise Attempt::Invalid, "Bad question" unless facts(level).include?(fact_of(a, b))

    given = result["given"].to_s
    raise Attempt::Invalid, "Bad answer" unless given.match?(Attempt::TYPED_ANSWER)

    { "a" => written(a), "b" => written(b), "given" => given, "correct" => given == written(a * b) }
  end

  # A question written and answered as the game would, as for a lesson's one to try
  def worked(question)
    a, b = question.values_at(:a, :b).map { |number| decimal(number) }
    { a: written(a), b: written(b), text: "#{shown(a)} × #{shown(b)}", answer: written(a * b) }
  end

  # "7 × 8 = 56", "0.7 × 3000 = 2100"
  def label(result)
    a, b = result.values_at("a", "b").map { |number| decimal(number) }
    "#{shown(a)} × #{shown(b)} = #{shown(a * b)}"
  end

  # Groups: each times table

  def group_label(table)
    "#{table}×"
  end

  def practise_message(tables)
    "Practise your #{tables.map { |table| group_label(table) }.to_sentence} tables"
  end

  def summary(best:, needs:)
    [ "Your best times table is #{best}", ("and the #{needs} times table needs the most practice" if needs) ].compact.join(", ") + "."
  end
end
