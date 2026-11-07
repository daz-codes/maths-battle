# The questions in every game: times tables and division, on tiers of difficulty from 2 × 3 up to 0.7 × 3000 and
# 2.1 ÷ 0.7. Which tier the next question comes from is set by the game's temperature: a running measure of how the
# player is doing, updated after every answer from whether it was right and how long it took. Quick right answers
# warm it up, so the questions get harder; slow ones barely move it, a very slow one cools it a little, and a wrong
# one cools it a lot, so the questions ease off until the player warms up again. In a battle that's what slows the
# leader down. Players never see the tiers: the questions just stay about as hard as they can manage.
#
# The server deals each tier a pool of questions for the game (deal), and the browser follows the temperature by the
# same rule (walk), taking each tier's next question in turn, round again if it runs out. The temperature is whole
# numbers only, so the browser and the server always agree, and as the walk depends only on the pools and each
# answer's result and time, the server can walk it again to check every answer was to the question the browser
# should have shown. A faster clock gains nothing: harder questions score no more
require "bigdecimal"

module Ladder
  extend self

  POOL = 30
  # A tier is DEGREES of temperature: three quick right answers move up one, and a wrong answer down one
  DEGREES = 100
  HEAT = { quick: 45, steady: 30, slow: 5, dawdle: -20, wrong: -100 }
  # How long a right answer at each tier usually takes: quick is under 60% of it, steady up to it, slow up to
  # twice it, and longer is dawdling. Harder tiers allow longer
  EXPECTED_MS = 2_000
  EXPECTED_MS_PER_TIER = 400
  # tables: the times tables asked; by: what they're multiplied by; divide: how often it's asked as a division;
  # places: how the numbers move by powers of ten (see powers)
  TIERS = [
    { name: "Warm up", example: "2 × 3", tables: [ 1, 2, 5, 10 ], by: 1..5, divide: 0, places: :none },
    { name: "Tables 2–5", example: "5 × 6", tables: [ 2, 3, 4, 5, 10 ], by: 1..10, divide: 0, places: :none },
    { name: "Tables to 10", example: "7 × 8", tables: 2..10, by: 2..10, divide: 0.3, places: :none },
    { name: "Tables to 12", example: "12 × 9", tables: 2..12, by: 2..12, divide: 0.5, places: :none },
    { name: "A zero", example: "30 × 4", tables: 2..12, by: 2..12, divide: 0.4, places: :one_zero },
    { name: "Zeroes", example: "40 × 300", tables: 2..12, by: 2..12, divide: 0.4, places: :zeroes },
    { name: "A decimal", example: "0.3 × 4", tables: 2..12, by: 2..12, divide: 0.4, places: :one_decimal },
    { name: "Decimals", example: "0.3 × 0.4", tables: 2..12, by: 2..12, divide: 0.4, places: :decimals },
    { name: "Zeroes and decimals", example: "0.7 × 3000", tables: 2..12, by: 2..12, divide: 0.4, places: :mixed },
    { name: "Expert", example: "0.08 × 700", tables: [ 6, 7, 8, 9, 12 ], by: 3..12, divide: 0.5, places: :mixed }
  ]
  OPERATIONS = %w[ x ÷ ]
  NUMBER = /\A\d{1,9}(\.\d{1,6})?\z/

  # Each tier's pool, as [ op, a, b ]: [ "x", "7", "8" ] is 7 × 8, [ "÷", "56", "8" ] is 56 ÷ 8
  def deal(random: Random.new)
    TIERS.map do |tier|
      previous = nil
      Array.new(POOL) { previous = question(tier, random, excluding: previous) }
    end
  end

  # The question asked for each answer, with the tier it was at, by the temperature. The browser follows the same
  # rule as it plays (test_controller.js). Yields each answer, its question and tier, and wants back whether it was
  # right and how many ms it took, or :skip for a question skipped, which leaves the temperature as it was.
  #
  # shifts move some questions to another tier for a while, whatever the temperature: { 12 => [ 9, 3 ] } asks the
  # 13th answer's question and the two after it from the hardest tier (a Curveball), and [ 0, 5 ] the easiest (a
  # Rocket). Returns the hottest tier the temperature reached, which the last answer may have warmed it to
  def walk(pools, answers, shifts: {})
    temperature, taken, highest = 0, Array.new(pools.size, 0), 0
    shifted_tier, shifted_left = nil, 0
    answers.each_with_index do |answer, index|
      shifted_tier, shifted_left = shifts[index] if shifts.key?(index)
      tier = shifted_left.positive? ? shifted_tier.clamp(0, pools.size - 1) : temperature / DEGREES
      shifted_left -= 1 if shifted_left.positive?
      pool = pools.fetch(tier)
      question = pool[taken[tier] % pool.size]
      taken[tier] += 1
      outcome = yield(answer, question, tier)
      next if outcome == :skip

      right, ms = outcome
      temperature = (temperature + heat(right, ms, tier)).clamp(0, pools.size * DEGREES - 1)
      highest = [ highest, temperature / DEGREES ].max
    end
    highest
  end

  # How much an answer warms the game up, or cools it down
  def heat(right, ms, tier)
    return HEAT[:wrong] unless right

    expected = EXPECTED_MS + EXPECTED_MS_PER_TIER * tier
    if ms * 10 <= expected * 6 then HEAT[:quick]
    elsif ms <= expected then HEAT[:steady]
    elsif ms <= expected * 2 then HEAT[:slow]
    else HEAT[:dawdle]
    end
  end

  # For the browser, to follow the same rule
  def rules
    { degrees: DEGREES, heat: HEAT, expectedMs: EXPECTED_MS, expectedMsPerTier: EXPECTED_MS_PER_TIER }
  end

  # For the browser: how it reads, and the answer as it's typed
  def worked((op, a, b))
    { op: op, a: a, b: b, text: "#{a} #{op == "x" ? "×" : "÷"} #{b}", answer: answer(op, a, b) }
  end

  def answer(op, a, b)
    x, y = decimal(a), decimal(b)
    written(op == "x" ? x * y : x / y)
  end

  # As typed: "2100", "0.42". Exact decimals, so 0.7 × 0.6 is 0.42, not 0.41999…
  def written(number)
    text = number.to_s("F")
    text.include?(".") ? text.sub(/0+\z/, "").delete_suffix(".") : text
  end

  private
    def question(tier, random, excluding:)
      loop do
        table, by = tier[:tables].to_a.sample(random: random), tier[:by].to_a.sample(random: random)
        numbers = random.rand < 0.5 ? [ table, by ] : [ by, table ]
        first, second = numbers.zip(powers(numbers, tier[:places], random)).map { |number, power| BigDecimal(number) * BigDecimal(10)**power }
        made = random.rand < tier[:divide] ? [ "÷", written(first * second), written(first) ] : [ "x", written(first), written(second) ]
        return made unless made == excluding
      end
    end

    # How many places each number moves: [ 1, 0 ] is 70 × 8, [ -1, 3 ] is 0.7 × 3000. 1 and 10 don't become
    # decimals, as 0.1 and 1.0 read oddly
    def powers(numbers, places, random)
      decimal = numbers.map { |number| ![ 1, 10 ].include?(number) }
      case places
      when :none then [ 0, 0 ]
      when :one_zero then [ [ 1, 0 ], [ 0, 1 ] ].sample(random: random)
      when :zeroes then random.rand(1..3).then { |total| first = random.rand(0..total); [ first, total - first ] }
      when :one_decimal then one_decimal(decimal, random)
      when :decimals then decimals(decimal, random)
      when :mixed then mixed(decimal, random)
      end
    end

    def one_decimal(decimal, random)
      choices = [ [ -1, 0 ], [ 0, -1 ] ].select { |powers| powers.each_with_index.all? { |power, i| power.zero? || decimal[i] } }
      choices.sample(random: random) || [ 0, 0 ]
    end

    # One or both numbers decimals: 0.3 × 0.4, 0.06 × 7, at most three places between them
    def decimals(decimal, random)
      return [ 0, 0 ] unless decimal.any?

      loop do
        powers = decimal.map { |can| can ? random.rand(-2..0) : 0 }
        return powers if powers.any?(&:negative?) && powers.sum >= -3
      end
    end

    # One a decimal and the other with zeroes: 0.7 × 3000, 0.08 × 700
    def mixed(decimal, random)
      return decimals(decimal, random) unless decimal.all?

      down, up = -random.rand(1..2), random.rand(1..3)
      random.rand < 0.5 ? [ down, up ] : [ up, down ]
    end

    def decimal(value)
      BigDecimal(value.to_s) if value.to_s.match?(NUMBER)
    end
end
