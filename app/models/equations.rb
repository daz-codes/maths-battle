# The equations topic: one and two step linear equations like 2x + 7 = 11 or m/3 − 1 = 2.
# The letter changes from question to question. Solutions are always positive, and may be fractions,
# which are answered top-heavy in lowest terms: 12x = 9 is 3/4, 9x = 11 is 11/9
module Equations
  TOPIC = "equations"
  SLUG = "equations"
  NAME = "Equations"
  EMOJI = "⚖️"

  # Each type of equation is a "fact": accuracy and speed are tracked per type, and the weighting picks types.
  # Fractions can only come out of types where the letter is multiplied
  TYPES = {
    "x+a=b"      => { difficulty: 0, fractions: false, example: "x + 5 = 9" },
    "x-a=b"      => { difficulty: 0, fractions: false, example: "x − 3 = 8" },
    "x/a=b"      => { difficulty: 0, fractions: false, example: "x/4 = 3" },
    "ax=b"       => { difficulty: 1, fractions: true,  example: "3x = 12" },
    "ax+b=c"     => { difficulty: 1, fractions: true,  example: "2x + 7 = 11" },
    "ax-b=c"     => { difficulty: 1, fractions: true,  example: "5x − 2 = 13" },
    "x/a+b=c"    => { difficulty: 2, fractions: false, example: "x/3 + 1 = 5" },
    "x/a-b=c"    => { difficulty: 2, fractions: false, example: "x/3 − 1 = 2" },
    "a(x+b)=c"   => { difficulty: 2, fractions: true,  example: "4(x + 2) = 30" },
    "(x+a)/b=c"  => { difficulty: 2, fractions: false, example: "(x + 3)/5 = 2" }
  }
  # Letters that can't be mistaken for a number or for each other (no i, l, o, s)
  VARIABLES = %w[ x y a b c d k m n p t w z h g r ]
  FRACTION_CHANCE = 0.35
  # How often the equation is written the other way round: 11 = 2x + 7
  FLIP_CHANCE = 0.25
  # The largest number the server accepts in a question sent back (well above anything generated)
  MAX_NUMBER = 999
  GIVEN_FORMAT = %r{\A\d{1,4}(/\d{1,4})?\z}

  extend self

  def fractions?
    true
  end

  # Facts: equation types

  def facts
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

  def question(type, random:)
    numbers = build(type, random)
    question = { type: type, **numbers, v: VARIABLES.sample(random: random), flip: random.rand < FLIP_CHANCE }
    question.merge(text: html(question), answer: written(solve(question)))
  end

  # Re-solves the equation from its numbers, so the score never depends on the browser
  def clean_result(result)
    question = question_from(result)
    solution = solve(question)
    raise Attempt::Invalid, "Bad question" unless solution.positive?

    given = result["given"].to_s
    raise Attempt::Invalid, "Bad answer" unless given.match?(GIVEN_FORMAT)

    question.transform_keys(&:to_s).merge("given" => given, "correct" => given == written(solution))
  end

  # "2y + 7 = 11, so y = 2"
  def label(result)
    question = question_from(result)
    "#{plain(question)}, so #{question[:v]} = #{written(solve(question))}"
  end

  # Groups: each type of equation

  def groups
    facts
  end

  def groups_of(type)
    [ type ]
  end

  def group_label(type)
    TYPES.fetch(type)[:example]
  end

  def group_heading
    "Type"
  end

  def rankable_group?(_type)
    true
  end

  def feedback_groups
    groups
  end

  def practise_message(types)
    "Practise equations like #{types.map { |type| group_label(type) }.to_sentence}"
  end

  def summary(best:, needs:)
    [ "You're best at equations like #{best}", ("and equations like #{needs} need the most practice" if needs) ].compact.join(", ") + "."
  end

  # 3/4 for three quarters, 4 for four
  def written(solution)
    solution.denominator == 1 ? solution.numerator.to_s : "#{solution.numerator}/#{solution.denominator}"
  end

  def solve(question)
    a, b, c = question.values_at(:a, :b, :c).map { |number| number && Rational(number) }

    case question[:type]
    when "x+a=b"     then b - a
    when "x-a=b"     then b + a
    when "x/a=b"     then a * b
    when "ax=b"      then b / a
    when "ax+b=c"    then (c - b) / a
    when "ax-b=c"    then (c + b) / a
    when "x/a+b=c"   then a * (c - b)
    when "x/a-b=c"   then a * (c + b)
    when "a(x+b)=c"  then c / a - b
    when "(x+a)/b=c" then b * c - a
    end
  end

  private
    # Builds the numbers from a solution chosen first, so every equation works out
    def build(type, random)
      case type
      when "x+a=b"     then plus(random)
      when "x-a=b"     then minus(random)
      when "x/a=b"     then divided(random)
      when "ax=b"      then times(solution(random), random)
      when "ax+b=c"    then times_plus(solution(random), random)
      when "ax-b=c"    then times_minus(solution(random), random)
      when "x/a+b=c"   then divided_plus(random)
      when "x/a-b=c"   then divided_minus(random)
      when "a(x+b)=c"  then bracket(solution(random), random)
      when "(x+a)/b=c" then over(random)
      end
    end

    # A whole number, or for some questions a fraction like 3/4 or 11/9 (never a whole one like 6/3)
    def solution(random)
      return Rational(random.rand(1..12)) unless random.rand < FRACTION_CHANCE

      denominator = random.rand(2..9)
      numerator = random.rand(1..denominator * 3) until numerator && numerator.gcd(denominator) == 1 && numerator % denominator != 0
      Rational(numerator, denominator)
    end

    # What the letter is multiplied by: a multiple of the solution's denominator, so the other numbers are whole
    def multiplier(solution, random, up_to: 12)
      denominator = solution.denominator
      denominator == 1 ? random.rand(2..up_to) : denominator * random.rand(1..[ up_to / denominator, 1 ].max)
    end

    def plus(random)
      x, a = random.rand(1..15), random.rand(1..15)
      { a: a, b: x + a }
    end

    def minus(random)
      x = random.rand(2..20)
      a = random.rand(1..x - 1)
      { a: a, b: x - a }
    end

    def divided(random)
      { a: random.rand(2..9), b: random.rand(1..12) }
    end

    def times(solution, random)
      a = multiplier(solution, random)
      { a: a, b: (a * solution).to_i }
    end

    def times_plus(solution, random)
      a = multiplier(solution, random)
      b = random.rand(1..15)
      { a: a, b: b, c: (a * solution).to_i + b }
    end

    def times_minus(solution, random)
      a = multiplier(solution, random)
      a *= 2 while a * solution < 2
      product = (a * solution).to_i
      b = random.rand(1..[ product - 1, 15 ].min)
      { a: a, b: b, c: product - b }
    end

    def divided_plus(random)
      a, quotient, b = random.rand(2..9), random.rand(1..10), random.rand(1..12)
      { a: a, b: b, c: quotient + b }
    end

    def divided_minus(random)
      a, quotient = random.rand(2..9), random.rand(2..12)
      b = random.rand(1..quotient - 1)
      { a: a, b: b, c: quotient - b }
    end

    # Smaller numbers, as the bracket is already the hard part: 4(x + 2) = 30
    def bracket(solution, random)
      a = multiplier(solution, random, up_to: 6)
      b = random.rand(1..6)
      { a: a, b: b, c: (a * (solution + b)).to_i }
    end

    def over(random)
      b, c = random.rand(2..9), random.rand(1..10)
      { a: random.rand(1..[ b * c - 1, 15 ].min), b: b, c: c }
    end

    def question_from(result)
      type = result["type"]
      raise Attempt::Invalid, "Bad question" unless TYPES.key?(type) && VARIABLES.include?(result["v"])

      numbers = %w[ a b c ].to_h { |key| [ key.to_sym, Integer(result[key], exception: false) ] }
      raise Attempt::Invalid, "Bad question" unless numbers.values_at(*numbers_used(type)).all? { |number| number&.between?(1, MAX_NUMBER) }

      { type: type, **numbers.slice(*numbers_used(type)), v: result["v"], flip: ActiveModel::Type::Boolean.new.cast(result["flip"]) || false }
    end

    def numbers_used(type)
      type.count("abc") == 3 ? %i[ a b c ] : %i[ a b ]
    end

    # Written out

    # Written on one line, so a top with more than one term needs brackets: (x + 3)/5
    def plain(question)
      over = ->(top, bottom) { top.to_s.include?(" ") ? "(#{top})/#{bottom}" : "#{top}/#{bottom}" }
      sides(question, letter: question[:v], over: over)
    end

    def html(question)
      letter = %(<var>#{question[:v]}</var>)
      over = ->(top, bottom) { %(<span class="frac"><span>#{top}</span><span>#{bottom}</span></span>) }
      sides(question, letter: letter, over: over)
    end

    def sides(question, letter:, over:)
      left, right = expression(question, letter, over)
      question[:flip] ? "#{right} = #{left}" : "#{left} = #{right}"
    end

    def expression(question, x, over)
      a, b, c = question.values_at(:a, :b, :c)

      case question[:type]
      when "x+a=b"     then [ "#{x} + #{a}", b ]
      when "x-a=b"     then [ "#{x} − #{a}", b ]
      when "x/a=b"     then [ over.(x, a), b ]
      when "ax=b"      then [ "#{a}#{x}", b ]
      when "ax+b=c"    then [ "#{a}#{x} + #{b}", c ]
      when "ax-b=c"    then [ "#{a}#{x} − #{b}", c ]
      when "x/a+b=c"   then [ "#{over.(x, a)} + #{b}", c ]
      when "x/a-b=c"   then [ "#{over.(x, a)} − #{b}", c ]
      when "a(x+b)=c"  then [ "#{a}(#{x} + #{b})", c ]
      when "(x+a)/b=c" then [ over.("#{x} + #{a}", b), c ]
      end
    end
end
