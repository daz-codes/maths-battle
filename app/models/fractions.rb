# The fractions topic: simplifying, then adding and subtracting with the same denominator, then different ones,
# then multiplying and dividing. Each level practises its own skill; mixed practice mixes them. Answers are
# in lowest terms, top-heavy when they're more than one (7/4), and whole numbers on their own (1)
module Fractions
  TOPIC = "fractions"
  SLUG = "fractions"
  NAME = "Fractions"
  EMOJI = "🍕"

  # Each kind of question is a "fact": accuracy and speed are tracked per kind, and the weighting picks kinds
  TYPES = {
    "simplify" => { difficulty: 0, form: "Simplifying", example: "6/8 = 3/4" },
    "add-same" => { difficulty: 0, form: "Adding, same denominator", example: "1/5 + 2/5" },
    "sub-same" => { difficulty: 0, form: "Subtracting, same denominator", example: "5/7 − 2/7" },
    "add-diff" => { difficulty: 1, form: "Adding, different denominators", example: "1/3 + 1/4" },
    "sub-diff" => { difficulty: 1, form: "Subtracting, different denominators", example: "3/4 − 1/6" },
    "multiply" => { difficulty: 1, form: "Multiplying", example: "2/3 × 3/5" },
    "divide"   => { difficulty: 2, form: "Dividing", example: "3/4 ÷ 1/2" }
  }
  OPERATORS = { "add-same" => "+", "sub-same" => "−", "add-diff" => "+", "sub-diff" => "−", "multiply" => "×", "divide" => "÷" }

  LEVELS = [
    { number: 1, name: "Simplifying", example: "6/8 = 3/4", types: %w[ simplify ] },
    { number: 2, name: "Same denominators", example: "1/5 + 2/5", types: %w[ add-same sub-same ] },
    { number: 3, name: "Different denominators", example: "1/3 + 1/4", types: %w[ add-diff sub-diff ] },
    { number: 4, name: "Multiplying", example: "2/3 × 3/5", types: %w[ multiply ] },
    { number: 5, name: "Dividing", example: "3/4 ÷ 1/2", types: %w[ divide ] }
  ]
  # Denominators the questions use, and the largest a common denominator gets, so it's mental maths
  DENOMINATORS = 2..10
  MAX_COMMON_DENOMINATOR = 40
  # Quick and lightning gems, allowing for some working out
  GEM_TIMES = { lightning: 4_000, quick: 8_000 }
  # A level's practice earns 1, 2 or 3 stars for its score; the first star unlocks the next level
  STARS = { 3 => 20, 2 => 10, 1 => 5 }
  # Scores in one game that earn a badge. Like equations: each question takes some working out
  BADGE_SCORES = [ 5, 10, 20, 30, 50 ]
  # The largest number the server accepts in a question sent back (well above anything generated)
  MAX_NUMBER = 999

  extend Topic::Playable
  extend self

  # Every answer is a fraction, so the keypad always has the fraction line
  def keys(_level)
    [ "/" ]
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
    question = { type: type, **build(type, random) }
    question.merge(text: html(question), answer: written(value(question)))
  end

  # Works the answer out again from the numbers, so the score never depends on the browser. A question from this
  # level or an easier one (mixed practice mixes them), with numbers the game could have asked
  def clean_result(result, level: 1)
    question = question_from(result)
    raise Attempt::Invalid, "Bad question" unless facts_through(level).include?(question[:type]) && possible?(question)

    given = result["given"].to_s
    raise Attempt::Invalid, "Bad answer" unless given.match?(Attempt::TYPED_ANSWER)

    question.transform_keys(&:to_s).merge("given" => given, "correct" => given == written(value(question)))
  end

  # A lesson's one to try, written and answered as the game would
  def worked(question)
    question.merge(text: html(question), answer: written(value(question)))
  end

  # "6/8 = 3/4", "1/3 + 1/4 = 7/12"
  def label(result)
    question = question_from(result)
    "#{plain(question)} = #{written(value(question))}"
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
    "Practise fractions like #{types.map { |type| group_example(type) }.to_sentence}"
  end

  def summary(best:, needs:)
    [ "You're best at #{best}", ("and #{needs} needs the most practice" if needs) ].compact.join(", ") + "."
  end

  def value(question)
    first = Rational(question[:a], question[:b])
    return first if question[:type] == "simplify"

    second = Rational(question[:c], question[:d])
    case question[:type]
    when "add-same", "add-diff" then first + second
    when "sub-same", "sub-diff" then first - second
    when "multiply"             then first * second
    when "divide"               then first / second
    end
  end

  # 3/4, 7/4, or 2 when it's whole
  def written(value)
    value.denominator == 1 ? value.numerator.to_s : "#{value.numerator}/#{value.denominator}"
  end

  private
    def level_details(number)
      level(number) || raise(Attempt::Invalid, "Unknown level")
    end

    # Questions

    def build(type, random)
      case type
      when "simplify"             then simplifiable(random)
      when "add-same", "sub-same" then same_denominator(type, random)
      when "add-diff", "sub-diff" then different_denominators(type, random)
      when "multiply", "divide"   then two_fractions(random)
      end
    end

    # A fraction in lowest terms, scaled up: 3/4 becomes 6/8 or 15/20
    def simplifiable(random)
      bottom = random.rand(2..10)
      top = coprime(bottom, random)
      scale = random.rand(2..[ MAX_COMMON_DENOMINATOR / bottom, 6 ].min)
      { a: top * scale, b: bottom * scale }
    end

    # Two proper fractions over the same denominator; a subtraction takes a smaller one from a larger
    def same_denominator(type, random)
      bottom = random.rand(3..12)
      if type == "sub-same"
        a = random.rand(2...bottom)
        { a: a, b: bottom, c: random.rand(1...a), d: bottom }
      else
        { a: random.rand(1...bottom), b: bottom, c: random.rand(1...bottom), d: bottom }
      end
    end

    # Two proper fractions with different denominators whose common denominator stays small
    def different_denominators(type, random)
      loop do
        b, d = random.rand(DENOMINATORS), random.rand(DENOMINATORS)
        next if b == d || b.lcm(d) > MAX_COMMON_DENOMINATOR

        numbers = { a: coprime(b, random), b: b, c: coprime(d, random), d: d }
        next if type == "sub-diff" && Rational(numbers[:a], b) <= Rational(numbers[:c], d)

        return numbers
      end
    end

    # Two proper fractions in lowest terms, to multiply or divide
    def two_fractions(random)
      b, d = random.rand(2..10), random.rand(2..10)
      { a: coprime(b, random), b: b, c: coprime(d, random), d: d }
    end

    # A top for this bottom that makes a proper fraction in lowest terms
    def coprime(bottom, random)
      top = random.rand(1...bottom) until top && top.gcd(bottom) == 1
      top
    end

    # Checking a question sent back

    def question_from(result)
      type = result["type"]
      raise Attempt::Invalid, "Bad question" unless TYPES.key?(type)

      numbers = %w[ a b c d ].to_h { |key| [ key.to_sym, Integer(result[key], exception: false) ] }.slice(*numbers_used(type))
      raise Attempt::Invalid, "Bad question" unless numbers.values.all? { |number| number&.between?(1, MAX_NUMBER) }

      { type: type, **numbers }
    end

    def numbers_used(type)
      type == "simplify" ? %i[ a b ] : %i[ a b c d ]
    end

    # Proper fractions the game could have asked: one to simplify that does simplify, the same or different
    # denominators as the kind says, and a subtraction that doesn't go below zero
    def possible?(question)
      a, b, c, d = question.values_at(:a, :b, :c, :d)
      return a < b && a.gcd(b) > 1 if question[:type] == "simplify"
      return false unless a < b && c < d

      case question[:type]
      when "add-same", "sub-same" then b == d && value(question).positive?
      when "add-diff", "sub-diff" then b != d && value(question).positive?
      else true
      end
    end

    # Written out: stacked for the game, on one line for the results page

    # In the game a fraction on its own says what to do with it
    def html(question)
      over = ->(top, bottom) { %(<span class="frac"><span>#{top}</span><span>#{bottom}</span></span>) }
      fractions = written_out(question, over)
      question[:type] == "simplify" ? %(<span class="question__verb">Simplify</span> #{fractions}) : fractions
    end

    def plain(question)
      written_out(question, ->(top, bottom) { "#{top}/#{bottom}" })
    end

    def written_out(question, over)
      a, b, c, d = question.values_at(:a, :b, :c, :d)
      return over.(a, b) if question[:type] == "simplify"

      "#{over.(a, b)} #{OPERATORS.fetch(question[:type])} #{over.(c, d)}"
    end
end
