# The questions in every game: times tables and division, on a ladder of tiers from 2 × 3 up to 0.7 × 3000 and
# 2.1 ÷ 0.7. A game starts at the bottom; CLIMB right answers in a row at a tier move up one, and a wrong answer
# moves down one. So a player doing well gets harder and harder questions until they slip, and one who's struggling
# gets easier ones until they're right again. In a battle that's what slows the leader down.
#
# The server deals each tier a pool of questions for the game (deal), and the browser walks them by the same rule
# (walk), taking each tier's next question in turn, round again if it runs out. As the walk depends only on the
# pools and which answers were right, the server can walk them again to check every answer was to the question the
# browser should have shown
require "bigdecimal"

module Ladder
  extend self

  CLIMB = 3
  POOL = 30
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

  # The question asked for each answer, with the tier it was at, by the climbing rule. The browser follows the same
  # rule as it plays (test_controller.js). Yields each answer, its question and tier, and wants back whether it was
  # right. Returns the highest tier reached, which the last answer may have climbed to
  def walk(pools, answers)
    tier, in_a_row, taken, highest = 0, 0, Array.new(pools.size, 0), 0
    answers.each do |answer|
      pool = pools.fetch(tier)
      question = pool[taken[tier] % pool.size]
      taken[tier] += 1
      right = yield(answer, question, tier)
      if right
        in_a_row += 1
        if in_a_row >= CLIMB && tier < pools.size - 1
          tier += 1
          in_a_row = 0
          highest = [ highest, tier ].max
        end
      else
        tier = [ tier - 1, 0 ].max
        in_a_row = 0
      end
    end
    highest
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

  def tier_name(tier)
    TIERS.fetch(tier)[:name]
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
