# The negative numbers topic: going below zero, starting below zero, adding and subtracting negatives, then
# multiplying and dividing them. Each level practises its own skill; mixed practice mixes them. A negative
# number added, taken away, multiplied or divided by is written in brackets: −3 + (−4), 6 × (−4)
module Negatives
  TOPIC = "negatives"
  SLUG = "negative-numbers"
  NAME = "Negative numbers"
  # Below zero on a thermometer
  EMOJI = "🌡️"

  # Each kind of question is a "fact": accuracy and speed are tracked per kind, and the weighting picks kinds
  TYPES = {
    "below-zero"        => { difficulty: 0, form: "Going below zero", example: "4 − 9" },
    "from-negative"     => { difficulty: 1, form: "Starting below zero", example: "−4 + 2" },
    "add-negative"      => { difficulty: 1, form: "Adding a negative", example: "−3 + (−4)" },
    "subtract-negative" => { difficulty: 2, form: "Subtracting a negative", example: "−5 − (−7)" },
    "multiply"          => { difficulty: 1, form: "Multiplying", example: "−6 × 4" },
    "divide"            => { difficulty: 2, form: "Dividing", example: "−24 ÷ (−6)" }
  }
  OPERATORS = { "below-zero" => "−", "add-negative" => "+", "subtract-negative" => "−", "multiply" => "×", "divide" => "÷" }
  LEVELS = [
    { number: 1, name: "Going below zero", example: "4 − 9", types: %w[ below-zero ] },
    { number: 2, name: "Starting below zero", example: "−4 + 2", types: %w[ below-zero from-negative ] },
    { number: 3, name: "Adding negatives", example: "−3 + (−4)", types: %w[ add-negative ] },
    { number: 4, name: "Subtracting negatives", example: "−5 − (−7)", types: %w[ subtract-negative ] },
    { number: 5, name: "Multiplying and dividing", example: "−6 × 4", types: %w[ multiply divide ] }
  ]
  # The numbers in a question, before signs: small enough for mental maths
  NUMBERS = 1..12
  GEM_TIMES = { lightning: 2_000, quick: 4_000 }
  # A level's practice earns 1, 2 or 3 stars for its score; the first star unlocks the next level
  STARS = { 3 => 20, 2 => 10, 1 => 5 }
  BADGE_SCORES = [ 5, 10, 20, 30, 50 ]
  # The largest number the server accepts in a question sent back (well above anything generated)
  MAX_NUMBER = 999

  extend Topic::Playable
  extend self

  # Answers can be negative from the start
  def keys(_level)
    [ "-" ]
  end

  # Facts: kinds of question. A level's practice asks only its own; mixed practice mixes in the ones before

  def facts(level = 1)
    level_details(level)[:types]
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

  def question(type, level: 1, random:)
    worked(type: type, **build(type, random))
  end

  # Works the answer out again from the numbers, so the score never depends on the browser. A question from this
  # level or an easier one (mixed practice mixes them), of a kind its numbers fit
  def clean_result(result, level: 1)
    question = question_from(result)
    raise Attempt::Invalid, "Bad question" unless facts_through(level).include?(question[:type]) && possible?(question)

    given = result["given"].to_s
    raise Attempt::Invalid, "Bad answer" unless given.match?(Attempt::TYPED_ANSWER)

    question.transform_keys(&:to_s).merge("given" => given, "correct" => given == value(question).to_s)
  end

  # A question written and answered as the game would, as for a lesson's one to try
  def worked(question)
    question.merge(text: written(question), answer: value(question).to_s)
  end

  # "−3 + (−4) = −7"
  def label(result)
    question = question_from(result)
    "#{written(question)} = #{number(value(question))}"
  end

  # Groups: each kind of question

  def groups(level = max_level)
    facts(level)
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

  def feedback_groups(level)
    groups(level)
  end

  def practise_message(types)
    "Practise questions like #{types.map { |type| group_example(type) }.to_sentence}"
  end

  def summary(best:, needs:)
    [ "You're best at #{best.downcase}", ("and #{needs.downcase} needs the most practice" if needs) ].compact.join(", ") + "."
  end

  def value(question)
    a, b = question.values_at(:a, :b)

    case question[:type]
    when "below-zero", "subtract-negative" then a - b
    when "from-negative", "add-negative"   then a + b
    when "multiply"                        then a * b
    when "divide"                          then a / b
    end
  end

  private
    def level_details(number)
      level(number) || raise(Attempt::Invalid, "Unknown level")
    end

    # Questions

    def build(type, random)
      case type
      when "below-zero"        then below_zero(random)
      when "from-negative"     then from_negative(random)
      when "add-negative"      then { a: any_sign(random), b: -small(random) }
      when "subtract-negative" then { a: any_sign(random), b: -small(random) }
      when "multiply"          then signed_pair(random)
      when "divide"            then signed_pair(random).then { |pair| { a: pair[:a] * pair[:b], b: pair[:b] } }
      end
    end

    def small(random)
      random.rand(NUMBERS)
    end

    def any_sign(random)
      small(random) * (random.rand < 0.5 ? -1 : 1)
    end

    # 4 − 9: a positive number take away a bigger one
    def below_zero(random)
      a = random.rand(1..11)
      { a: a, b: random.rand(a + 1..NUMBERS.max + a) }
    end

    # −2 − 9, −4 + 2, −3 + 5: a negative number, then add or take away a positive one. Taking away is kept as
    # adding a negative b, written without brackets as − 9
    def from_negative(random)
      { a: -small(random), b: any_sign(random) }
    end

    # A table fact with signs, usually at least one negative: −7 × 8, −6 × −4
    def signed_pair(random)
      signs = [ random.rand < 0.5 ? -1 : 1, random.rand < 0.5 ? -1 : 1 ]
      signs[random.rand(2)] = -1 if signs.all?(&:positive?)
      { a: random.rand(2..12) * signs[0], b: random.rand(2..12) * signs[1] }
    end

    # Checking a question sent back

    def question_from(result)
      type = result["type"]
      raise Attempt::Invalid, "Bad question" unless TYPES.key?(type)

      a, b = result.values_at("a", "b").map { |number| Integer(number, exception: false) }
      raise Attempt::Invalid, "Bad question" unless [ a, b ].all? { |number| number&.abs&.between?(1, MAX_NUMBER) }

      { type: type, a: a, b: b }
    end

    # Numbers the game could have asked: each kind has its own signs, and a division comes out whole
    def possible?(question)
      a, b = question.values_at(:a, :b)

      case question[:type]
      when "below-zero"                        then a.positive? && b > a
      when "from-negative"                     then a.negative?
      when "add-negative", "subtract-negative" then b.negative?
      when "multiply"                          then a.negative? || b.negative?
      when "divide"                            then (a.negative? || b.negative?) && (a % b).zero?
      end
    end

    # Written out

    # −3 + (−4): the first number as it is, the second in brackets if it's negative. Starting below zero, taking
    # away is just that: −2 − 9
    def written(question)
      a, b = question.values_at(:a, :b)
      return "#{number(a)} #{b.negative? ? "−" : "+"} #{b.abs}" if question[:type] == "from-negative"

      second = b.negative? ? "(#{number(b)})" : number(b)
      "#{number(a)} #{OPERATORS.fetch(question[:type])} #{second}"
    end

    # With a proper minus sign: −4
    def number(value)
      value.negative? ? "−#{value.abs}" : value.to_s
    end
end
