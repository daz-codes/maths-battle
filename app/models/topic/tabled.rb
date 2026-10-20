# What times tables and division share. Each question rests on a table fact like 7 × 8, and players are tracked
# and grouped by table. Higher levels move the numbers by powers of ten: zeroes (70 × 8), then decimals (0.7 × 3),
# then both (0.7 × 3000), so the weighting towards the facts a player finds hard works at every level.
# A topic includes this and says how its questions read and how an answer is checked
require "bigdecimal"

module Topic::Tabled
  FACTORS = 1..12
  # Tables almost everyone finds trivial: asked rarely, and left out of best/worst rankings
  TRIVIAL_FACTORS = [ 1, 10 ]
  # How hard each table usually is for children, 0 (easy) to 2 (hard)
  DIFFICULTY = { 1 => 0, 2 => 0, 5 => 0, 10 => 0, 3 => 1, 4 => 1, 11 => 1, 6 => 2, 7 => 2, 8 => 2, 9 => 2, 12 => 2 }
  FIRST_TABLES = 2..5
  # The powers of ten each level can move a number by: 3 means ×1000, −2 means ÷100
  POWERS = { 1 => 0..0, 2 => 0..0, 3 => 0..3, 4 => -2..0, 5 => -2..3 }
  # Between them the two numbers move by at most this many places, so answers stay typeable
  MAX_PLACES = 3
  # Signed, as games from when times tables had a negatives level are still read for history and feedback.
  # New answers are positive (allowed?)
  NUMBER_FORMAT = /\A-?\d{1,9}(\.\d{1,6})?\z/

  # A decimal point once the level has decimals
  def keys(level)
    POWERS.fetch(level).min.negative? ? [ "." ] : []
  end

  # Facts

  # Every fact once, smaller number first: "1x1", "1x2" … "12x12". 7×8 and 8×7 are the same fact.
  # Level 1 is just the 2–5 tables
  def facts(level = 1)
    all = FACTORS.to_a.repeated_combination(2).map { |a, b| "#{a}x#{b}" }
    level == 1 ? all.select { |fact| factors(fact).intersect?(FIRST_TABLES.to_a) } : all
  end

  # A fact is as hard as its harder table: 2×7 is easy, 7×8 is hard
  def difficulty(fact)
    factors(fact).map { |factor| DIFFICULTY.fetch(factor) }.max
  end

  def trivial?(fact)
    factors(fact).intersect?(TRIVIAL_FACTORS)
  end

  # Groups: each table

  def groups(_level = nil)
    FACTORS.to_a
  end

  # 7×8 counts toward both the 7 and 8 tables, 7×7 once
  def groups_of(fact)
    factors(fact).uniq
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

  # As typed: "2100", "0.42". Exact decimals, so 0.7 × 0.6 is 0.42, not 0.41999…
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

    # The table fact under two numbers: 0.7 and 3000 are 7 × 3
    def fact_of(*numbers)
      numbers.map { |number| base(number) }.minmax.join("x")
    end

    # A fact's two numbers, either way round, moved by powers of ten for the level: 70 and 8, 0.7 and 3000
    def scaled_factors(fact, level, random)
      numbers = random.rand < 0.5 ? factors(fact) : factors(fact).reverse
      numbers.zip(powers(numbers, level, random)).map { |number, power| BigDecimal(number) * BigDecimal(10)**power }
    end

    def powers(numbers, level, random)
      case level
      when 1, 2 then [ 0, 0 ]
      when 3 then zeroes(random)
      else decimals(numbers, level, random)
      end
    end

    # 70 × 8, 40 × 300: between one and three zeroes, spread across the numbers
    def zeroes(random)
      places = random.rand(1..MAX_PLACES)
      first = random.rand(0..places)
      [ first, places - first ]
    end

    # 0.7 × 3, 0.4 × 0.6: at least one decimal. At the top level one has zeroes too, 0.7 × 3000, if both can
    # move: 1 and 10 stay whole, as 0.1 and 1.0 would read oddly
    def decimals(numbers, level, random)
      scalable = numbers.map { |number| ![ 1, 10 ].include?(number) }
      return [ 0, 0 ] unless scalable.any?

      zeroes_too = POWERS.fetch(level).max.positive? && scalable.all?
      loop do
        powers = scalable.map { |can| can ? random.rand(POWERS.fetch(level)) : 0 }
        next unless powers.any?(&:negative?) && powers.sum.abs <= MAX_PLACES
        return powers unless zeroes_too && powers.none?(&:positive?)
      end
    end

    # The table number under a moved one: 3000 → 3, 0.7 → 7, 1.2 → 12
    def base(number)
      number = number.abs
      number *= 10 until number.frac.zero?
      number /= 10 while number > FACTORS.max && (number % 10).zero?
      number.to_i
    end

    def power(number)
      Math.log10(number.abs / base(number)).round
    end

    # A number the level could have asked: a table number moved by the level's powers of ten
    def allowed?(number, level)
      number.positive? && FACTORS.cover?(base(number)) && POWERS.fetch(level).cover?(power(number))
    end

    # As shown in a question: 3000, 0.7, and for an old negatives game a proper minus sign: −3000
    def shown(number)
      written(number).sub("-", "−")
    end
end
