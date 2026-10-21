# The adding and subtracting topic: single digits, then two digits, three digits, round numbers with zeroes,
# then decimals. Adding and subtracting are the two facts tracked, at every level; mixed practice mixes the
# levels. A subtraction never goes below zero: that's the negative numbers topic
require "bigdecimal"

module Addition
  TOPIC = "addition"
  SLUG = "adding-and-subtracting"
  NAME = "Adding and subtracting"
  EMOJI = "➕"

  TYPES = {
    "add"      => { difficulty: 0, form: "Adding", example: "47 + 38", sign: "+" },
    "subtract" => { difficulty: 1, form: "Subtracting", example: "82 − 46", sign: "−" }
  }
  LEVELS = [
    { number: 1, name: "Single digits", example: "8 + 7" },
    { number: 2, name: "Two digits", example: "47 + 38" },
    { number: 3, name: "Three digits", example: "347 + 285" },
    { number: 4, name: "Zeroes", example: "4700 − 2800" },
    { number: 5, name: "Decimals", example: "2.3 − 0.32" }
  ]
  STAR_TIMES = { lightning: 2_000, quick: 4_000 }
  # A level's practice earns a medal for its score; bronze unlocks the next level
  MEDALS = { gold: 20, silver: 10, bronze: 5 }
  BADGE_SCORES = [ 5, 10, 25, 50, 75 ]
  NUMBER_FORMAT = /\A\d{1,6}(\.\d{1,2})?\z/

  extend Topic::Playable
  extend self

  # A decimal point for the decimals level
  def keys(level)
    level >= 5 ? [ "." ] : []
  end

  # Facts: adding and subtracting

  def facts(_level = 1)
    TYPES.keys
  end

  def fact_key(result)
    result["type"]
  end

  def difficulty(type)
    TYPES.fetch(type)[:difficulty]
  end

  def trivial?(_type)
    false
  end

  # Questions

  # Two numbers for the level, added, or the smaller taken from the larger
  def question(type, level: 1, random:)
    a, b = numbers(type, level, random)
    worked(type: type, a: a, b: b)
  end

  # Worked out again from the numbers, so the score never depends on the browser. Numbers this level or an
  # easier one could have asked (mixed practice mixes them), and a subtraction that stays above zero
  def clean_result(result, level: 1)
    type = result["type"]
    a, b = result.values_at("a", "b").map { |number| decimal(number) }
    raise Attempt::Invalid, "Bad question" unless TYPES.key?(type) && a && b && (1..level).any? { |easier| fits?(a, b, easier) }
    raise Attempt::Invalid, "Bad question" if type == "subtract" && a <= b

    given = result["given"].to_s
    raise Attempt::Invalid, "Bad answer" unless given.match?(Attempt::TYPED_ANSWER)

    { "type" => type, "a" => written(a), "b" => written(b), "given" => given, "correct" => given == written(value(type, a, b)) }
  end

  # A question written and answered as the game would, as for a lesson's one to try
  def worked(question)
    a, b = question.values_at(:a, :b).map { |number| decimal(number) }
    type = question[:type]
    { type: type, a: written(a), b: written(b), text: "#{written(a)} #{TYPES.fetch(type)[:sign]} #{written(b)}", answer: written(value(type, a, b)) }
  end

  # "47 + 38 = 85"
  def label(result)
    a, b = result.values_at("a", "b").map { |number| decimal(number) }
    type = result["type"]
    "#{written(a)} #{TYPES.fetch(type)[:sign]} #{written(b)} = #{written(value(type, a, b))}"
  end

  # Groups: adding and subtracting

  def groups(_level = nil)
    TYPES.keys
  end

  def groups_of(type)
    [ type ]
  end

  def group_label(type)
    TYPES.fetch(type)[:form]
  end

  def group_example(type)
    TYPES.fetch(type)[:example]
  end

  def group_heading
    "Type"
  end

  def rankable_group?(_type)
    true
  end

  def feedback_groups(_level)
    groups
  end

  def practise_message(types)
    "Practise #{types.map { |type| group_label(type).downcase }.to_sentence(last_word_connector: " and ")}"
  end

  def summary(best:, needs:)
    [ "You're best at #{best.downcase}", ("and #{needs.downcase} needs the most practice" if needs) ].compact.join(", ") + "."
  end

  # As typed: "85", "1.98". Exact decimals, so 2.3 − 0.32 is 1.98
  def written(number)
    text = number.to_s("F")
    text.include?(".") ? text.sub(/0+\z/, "").delete_suffix(".") : text
  end

  private
    def value(type, a, b)
      type == "add" ? a + b : a - b
    end

    def decimal(value)
      BigDecimal(value.to_s) if value.to_s.match?(NUMBER_FORMAT)
    end

    # Questions

    def numbers(type, level, random)
      a, b = pair(level, random)
      a, b = [ a + b, a ] if type == "subtract" && level == 1
      a, b = [ a, b ].sort.reverse if type == "subtract"
      a == b ? numbers(type, level, random) : [ a, b ]
    end

    # Level 1's subtractions undo its additions: 15 − 9, from 9 + 6
    def pair(level, random)
      case level
      when 1 then [ random.rand(1..9), random.rand(1..9) ]
      when 2 then [ random.rand(10..99), random.rand < 0.3 ? random.rand(2..9) : random.rand(10..99) ]
      when 3 then [ random.rand(100..999), random.rand < 0.4 ? random.rand(10..99) : random.rand(100..999) ]
      when 4 then round_pair(random)
      else decimal_pair(random)
      end
    end

    # 470 + 380, 4700 − 2800: two-digit numbers with the same zeroes on the end
    def round_pair(random)
      zeroes = BigDecimal(10)**random.rand(1..3)
      [ random.rand(11..99) * zeroes, random.rand(11..99) * zeroes ]
    end

    # 4.7 + 3.8, 2.3 − 0.32: one or two decimal places each, often different
    def decimal_pair(random)
      Array.new(2) do
        places = random.rand(1..2)
        number = BigDecimal(random.rand(1..(places == 1 ? 99 : 999))) / BigDecimal(10)**places
        number.frac.zero? ? number + BigDecimal("0.1") : number
      end
    end

    # Numbers a level could have asked
    def fits?(a, b, level)
      whole = [ a, b ].all? { |number| number.frac.zero? }

      case level
      when 1 then whole && b <= 9 && (a <= 9 || a - b <= 9)
      when 2 then whole && [ a, b ].all? { |number| number < 100 }
      when 3 then whole && [ a, b ].all? { |number| number < 1000 }
      when 4 then whole && (1..3).any? { |places| [ a, b ].all? { |number| round?(number, places) } }
      else [ a, b ].all? { |number| number < 100 && (number * 100).frac.zero? }
      end
    end

    def round?(number, places)
      zeroes = BigDecimal(10)**places
      (number % zeroes).zero? && (number / zeroes) < 100
    end
end
