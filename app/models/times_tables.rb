# The times tables topic: what its questions are, how answers are checked, and how it's grouped (by table).
# Every topic answers the same questions, so the game, scoring, stats and feedback work for any of them.
#
# It has levels. Each question rests on a table fact like 7 × 3; higher levels scale its numbers by powers
# of ten and add signs (0.7 × −3000), so the weighting towards facts a player finds hard works at every level
require "bigdecimal"

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
  LEVELS = [
    { number: 1, name: "Tables 2–5", example: "4 × 3" },
    { number: 2, name: "Tables 2–12", example: "7 × 8" },
    { number: 3, name: "Zeroes", example: "40 × 300" },
    { number: 4, name: "Decimals", example: "0.7 × 3000" },
    { number: 5, name: "Negatives", example: "0.7 × −3000" }
  ]
  FIRST_TABLES = 2..5
  # A level's practice earns a medal for its score; bronze unlocks the next level
  MEDALS = { gold: 30, silver: 20, bronze: 10 }
  # A right answer under 1 second earns the lightning stars, under 2 the quick ones
  STAR_TIMES = { lightning: 1_000, quick: 2_000 }
  # Scores in one game that earn a badge
  BADGE_SCORES = [ 5, 10, 25, 50, 75, 100 ]
  # The powers of ten each level can scale a number by: 3 means ×1000, −2 means ÷100
  POWERS = { 1 => 0..0, 2 => 0..0, 3 => 0..3, 4 => -2..3, 5 => -2..3 }
  # Between them the two numbers move by at most this many places, so answers stay typeable
  MAX_PLACES = 3
  NEGATIVES_FROM = 5
  NUMBER_FORMAT = /\A-?\d{1,9}(\.\d{1,6})?\z/

  extend Topic::Playable
  extend self

  # Extra keypad keys beyond the digits
  def keys(level)
    [ ("-" if level >= NEGATIVES_FROM), ("." if POWERS.fetch(level).min.negative?) ].compact
  end

  # Facts

  # Every fact once, smaller number first: "1x1", "1x2" … "12x12". 7×8 and 8×7 are the same fact.
  # Level 1 is just the 2–5 tables
  def facts(level = 1)
    all = FACTORS.to_a.repeated_combination(2).map { |a, b| "#{a}x#{b}" }
    level == 1 ? all.select { |fact| factors(fact).intersect?(FIRST_TABLES.to_a) } : all
  end

  # The table fact under a question: 0.7 × −3000 is 7 × 3
  def fact_key(result)
    [ result["a"], result["b"] ].map { |number| base(decimal(number)) }.minmax.join("x")
  end

  # A fact is as hard as its harder table: 2×7 is easy, 7×8 is hard
  def difficulty(fact)
    factors(fact).map { |factor| DIFFICULTY.fetch(factor) }.max
  end

  def trivial?(fact)
    factors(fact).intersect?(TRIVIAL_FACTORS)
  end

  # Questions

  # Asked either way round: 7 × 8 or 8 × 7, scaled for the level: 70 × 8, 0.7 × −3000
  def question(fact, level: 1, random:)
    a, b = scaled(random.rand < 0.5 ? factors(fact) : factors(fact).reverse, level, random)
    { a: written(a), b: written(b), text: "#{shown(a)} × #{shown(b)}", answer: written(a * b) }
  end

  # The answers the browser sent, checked and scored here rather than trusted. The fact must be one the level
  # asks, so level 1 only takes the 2–5 tables
  def clean_result(result, level: 1)
    a, b = result.values_at("a", "b").map { |number| decimal(number) }
    raise Attempt::Invalid, "Bad question" unless [ a, b ].all? { |number| number && allowed?(number, level) }
    raise Attempt::Invalid, "Bad question" unless facts(level).include?(fact_key(result))

    given = result["given"].to_s
    raise Attempt::Invalid, "Bad answer" unless given.match?(Attempt::TYPED_ANSWER)

    { "a" => written(a), "b" => written(b), "given" => given, "correct" => given == written(a * b) }
  end

  # A lesson's one to try, written and answered as the game would
  def worked(question)
    a, b = question.values_at(:a, :b).map { |number| decimal(number) }
    { a: written(a), b: written(b), text: "#{shown(a)} × #{shown(b)}", answer: written(a * b) }
  end

  # "7 × 8 = 56", "0.7 × −3000 = −2100"
  def label(result)
    a, b = result.values_at("a", "b").map { |number| decimal(number) }
    "#{shown(a)} × #{shown(b)} = #{shown(a * b)}"
  end

  # Groups: each times table

  def groups(_level = nil)
    FACTORS.to_a
  end

  # 7×8 counts toward both the 7× and 8× tables, 7×7 once
  def groups_of(fact)
    factors(fact).uniq
  end

  def group_label(table)
    "#{table}×"
  end

  def group_example(_table)
    nil
  end

  def group_heading
    "Table"
  end

  def rankable_group?(table)
    TRIVIAL_FACTORS.exclude?(table)
  end

  # Feedback isn't given on the trivial tables
  def feedback_groups(_level)
    groups - TRIVIAL_FACTORS
  end

  def practise_message(tables)
    "Practise your #{tables.map { |table| group_label(table) }.to_sentence} tables"
  end

  def summary(best:, needs:)
    [ "Your best times table is #{best}", ("and the #{needs} times table needs the most practice" if needs) ].compact.join(", ") + "."
  end

  # As typed: "2100", "0.42", "-30". Exact decimals, so 0.7 × 0.6 is 0.42, not 0.41999…
  def written(number)
    text = number.to_s("F")
    text.include?(".") ? text.sub(/0+\z/, "").delete_suffix(".") : text
  end

  private
    def factors(fact)
      fact.split("x").map(&:to_i)
    end

    def decimal(value)
      BigDecimal(value.to_s) if value.to_s.match?(NUMBER_FORMAT)
    end

    # As shown in the question, with a proper minus sign: −3000
    def shown(number)
      written(number).sub("-", "−")
    end

    # Scales each number by a power of ten for the level, then for the top level maybe makes them negative
    def scaled(numbers, level, random)
      numbers = numbers.zip(powers(numbers, level, random)).map { |number, power| BigDecimal(number) * BigDecimal(10)**power }
      level >= NEGATIVES_FROM ? signed(numbers, random) : numbers
    end

    def powers(numbers, level, random)
      case level
      when 1, 2 then [ 0, 0 ]
      when 3 then zeroes(random)
      when 4 then decimals(numbers, random)
      else [ -> { [ 0, 0 ] }, -> { zeroes(random) }, -> { decimals(numbers, random) } ].sample(random: random).call
      end
    end

    # 70 × 8, 40 × 300: between one and three zeroes, spread across the numbers
    def zeroes(random)
      places = random.rand(1..MAX_PLACES)
      first = random.rand(0..places)
      [ first, places - first ]
    end

    # 0.7 × 3000, 0.4 × 0.6: at least one decimal. 1 and 10 stay whole, as 0.1 and 1.0 would read oddly
    def decimals(numbers, random)
      scalable = numbers.map { |number| ![ 1, 10 ].include?(number) }
      return [ 0, 0 ] unless scalable.any?

      loop do
        powers = scalable.map { |can| can ? random.rand(POWERS[4]) : 0 }
        return powers if powers.any?(&:negative?) && powers.sum.abs <= MAX_PLACES
      end
    end

    # Usually at least one negative: −7 × 8, −0.6 × −4
    def signed(numbers, random)
      signs = numbers.map { random.rand < 0.5 ? -1 : 1 }
      signs[random.rand(2)] = -1 if signs.all?(&:positive?) && random.rand < 0.7
      numbers.zip(signs).map { |number, sign| number * sign }
    end

    # The table number under a scaled one: 3000 → 3, 0.7 → 7, 1.2 → 12
    def base(number)
      number = number.abs
      number *= 10 until number.frac.zero?
      number /= 10 while number > FACTORS.max && (number % 10).zero?
      number.to_i
    end

    def power(number)
      Math.log10(number.abs / base(number)).round
    end

    # A number the level could have asked: a table number moved by the level's powers of ten, negative only at the top
    def allowed?(number, level)
      FACTORS.cover?(base(number)) && POWERS.fetch(level).cover?(power(number)) && (number.positive? || level >= NEGATIVES_FROM)
    end
end
