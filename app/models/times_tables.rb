# The times tables topic: what its questions are, how answers are checked, and how it's grouped (by table).
# Every topic answers the same questions, so the game, scoring, stats and feedback work for any of them
module TimesTables
  TOPIC = "times_tables"
  SLUG = "times-tables"
  NAME = "Times tables"
  EMOJI = "✖️"
  FACTORS = 1..12
  # Tables almost everyone finds trivial: asked rarely, and left out of best/worst rankings
  TRIVIAL_FACTORS = [ 1, 10 ]
  # How hard each table usually is for children, 0 (easy) to 2 (hard)
  DIFFICULTY = { 1 => 0, 2 => 0, 5 => 0, 10 => 0, 3 => 1, 4 => 1, 11 => 1, 6 => 2, 7 => 2, 8 => 2, 9 => 2, 12 => 2 }
  MAX_GIVEN = 999

  extend self

  def fractions?
    false
  end

  # Facts

  # Every fact once, smaller number first: "1x1", "1x2" … "12x12". 7×8 and 8×7 are the same fact
  def facts
    FACTORS.to_a.repeated_combination(2).map { |a, b| "#{a}x#{b}" }
  end

  def fact_key(result)
    [ result["a"], result["b"] ].minmax.join("x")
  end

  # A fact is as hard as its harder table: 2×7 is easy, 7×8 is hard
  def difficulty(fact)
    factors(fact).map { |factor| DIFFICULTY.fetch(factor) }.max
  end

  def trivial?(fact)
    factors(fact).intersect?(TRIVIAL_FACTORS)
  end

  # Questions

  # Asked either way round: 7 × 8 or 8 × 7
  def question(fact, random:)
    a, b = random.rand < 0.5 ? factors(fact) : factors(fact).reverse
    { a: a, b: b, text: "#{a} × #{b}", answer: (a * b).to_s }
  end

  # The answers the browser sent, checked and scored here rather than trusted
  def clean_result(result)
    a, b, given = result.values_at("a", "b", "given").map { |value| Integer(value, exception: false) }
    raise Attempt::Invalid, "Bad question" unless FACTORS.cover?(a) && FACTORS.cover?(b)
    raise Attempt::Invalid, "Bad answer" unless given&.between?(0, MAX_GIVEN)

    { "a" => a, "b" => b, "given" => given, "correct" => given == a * b }
  end

  # "7 × 8 = 56"
  def label(result)
    "#{result["a"]} × #{result["b"]} = #{result["a"] * result["b"]}"
  end

  # Groups: each times table

  def groups
    FACTORS.to_a
  end

  # 7×8 counts toward both the 7× and 8× tables, 7×7 once
  def groups_of(fact)
    factors(fact).uniq
  end

  def group_label(table)
    "#{table}×"
  end

  def group_heading
    "Table"
  end

  def rankable_group?(table)
    TRIVIAL_FACTORS.exclude?(table)
  end

  # Feedback isn't given on the trivial tables
  def feedback_groups
    groups - TRIVIAL_FACTORS
  end

  def practise_message(tables)
    "Practise your #{tables.map { |table| group_label(table) }.to_sentence} tables"
  end

  def summary(best:, needs:)
    [ "Your best times table is #{best}", ("and the #{needs} times table needs the most practice" if needs) ].compact.join(", ") + "."
  end

  private
    def factors(fact)
      fact.split("x").map(&:to_i)
    end
end
