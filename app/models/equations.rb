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
    "x+a=b"      => { difficulty: 0, form: "x + a = b",     example: "x + 5 = 9" },
    "x-a=b"      => { difficulty: 0, form: "x − a = b",     example: "x − 3 = 8" },
    "x/a=b"      => { difficulty: 0, form: "x/a = b",       example: "x/4 = 3" },
    "ax=b"       => { difficulty: 1, form: "ax = b",        example: "3x = 12" },
    "ax+b=c"     => { difficulty: 1, form: "ax + b = c",    example: "2x + 7 = 11" },
    "ax-b=c"     => { difficulty: 1, form: "ax − b = c",    example: "5x − 2 = 13" },
    "x/a+b=c"    => { difficulty: 2, form: "x/a + b = c",   example: "x/3 + 1 = 5" },
    "x/a-b=c"    => { difficulty: 2, form: "x/a − b = c",   example: "x/3 − 1 = 2" },
    "a(x+b)=c"   => { difficulty: 2, form: "a(x + b) = c",  example: "4(x + 2) = 30" },
    "(x+a)/b=c"  => { difficulty: 2, form: "(x + a)/b = c", example: "(x + 3)/5 = 2" }
  }
  ONE_STEP = %w[ x+a=b x-a=b x/a=b ax=b ]
  TWO_STEP = %w[ ax+b=c ax-b=c x/a+b=c x/a-b=c ]
  BRACKETS = %w[ a(x+b)=c (x+a)/b=c ]

  # Each level adds to the one before, so earlier levels' questions are always fair game.
  # The limits set how big the numbers get; fractions only come at the top level
  SMALL = { solution: 1..10, multiplier: 2..5, divisor: 2..5, addend: 1..10 }
  BIG = { solution: 1..20, multiplier: 2..12, divisor: 2..10, addend: 1..20 }
  LEVELS = [
    { number: 1, name: "One step", example: "x + 4 = 9", types: ONE_STEP, limits: SMALL, flip: false, fractions: false },
    { number: 2, name: "Bigger one step", example: "12x = 96", types: ONE_STEP, limits: BIG, flip: true, fractions: false },
    { number: 3, name: "Two step", example: "2x + 3 = 11", types: ONE_STEP + TWO_STEP, limits: SMALL, flip: true, fractions: false },
    { number: 4, name: "Bigger two step", example: "4(x + 3) = 36", types: ONE_STEP + TWO_STEP + BRACKETS, limits: BIG, flip: true, fractions: false },
    { number: 5, name: "Fractions", example: "12x = 9", types: ONE_STEP + TWO_STEP + BRACKETS, limits: BIG, flip: true, fractions: true }
  ]
  # Letters that can't be mistaken for a number or for each other (no i, l, o, s)
  VARIABLES = %w[ x y a b c d k m n p t w z h g r ]
  # At the fractions level, how often a question that could have a fraction answer does
  FRACTION_CHANCE = 0.5
  # How often the equation is written the other way round: 11 = 2x + 7
  FLIP_CHANCE = 0.25
  # The largest number the server accepts in a question sent back (well above anything generated)
  MAX_NUMBER = 999
  GIVEN_FORMAT = %r{\A\d{1,4}(/\d{1,4})?\z}

  extend self

  def levels
    LEVELS
  end

  # Extra keypad keys beyond the digits: the fraction line, only at the level with fraction answers
  def keys(level)
    level_details(level)[:fractions] ? [ "/" ] : []
  end

  # Facts: equation types

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
    details = level_details(level)
    numbers = build(type, details, random)
    question = { type: type, **numbers, v: VARIABLES.sample(random: random), flip: details[:flip] && random.rand < FLIP_CHANCE }
    question.merge(text: html(question), answer: written(solve(question)))
  end

  # Re-solves the equation from its numbers, so the score never depends on the browser
  # A question from this level or an easier one: its type must be in the level, and fractions only at the top
  def clean_result(result, level: 1)
    question = question_from(result)
    solution = solve(question)
    raise Attempt::Invalid, "Bad question" unless solution.positive? && facts(level).include?(question[:type])
    raise Attempt::Invalid, "Bad question" unless solution.denominator == 1 || level_details(level)[:fractions]

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

  def groups(level = Topic.max_level(self))
    facts(level)
  end

  def groups_of(type)
    [ type ]
  end

  # The form, ax + b = c, with an example to make it concrete
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
    "Practise equations like #{types.map { |type| group_example(type) }.to_sentence}"
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
    def level_details(level)
      Topic.level(self, level) || raise(Attempt::Invalid, "Unknown level")
    end

    # Builds the numbers from a solution chosen first, so every equation works out, within the level's limits
    def build(type, details, random)
      limits = details[:limits]

      case type
      when "x+a=b"     then plus(limits, random)
      when "x-a=b"     then minus(limits, random)
      when "x/a=b"     then divided(limits, random)
      when "ax=b"      then times(solution(details, random), limits, random)
      when "ax+b=c"    then times_plus(solution(details, random), limits, random)
      when "ax-b=c"    then times_minus(solution(details, random), limits, random)
      when "x/a+b=c"   then divided_plus(limits, random)
      when "x/a-b=c"   then divided_minus(limits, random)
      when "a(x+b)=c"  then bracket(solution(details, random), limits, random)
      when "(x+a)/b=c" then over(limits, random)
      end
    end

    # A whole number, or at the fractions level often a fraction like 3/4 or 11/9 (never a whole one like 6/3)
    def solution(details, random)
      return Rational(random.rand(details[:limits][:solution])) unless details[:fractions] && random.rand < FRACTION_CHANCE

      denominator = random.rand(2..9)
      numerator = random.rand(1..denominator * 3) until numerator && numerator.gcd(denominator) == 1 && numerator % denominator != 0
      Rational(numerator, denominator)
    end

    # What the letter is multiplied by: a multiple of the solution's denominator, so the other numbers are whole
    def multiplier(solution, limits, random, up_to: limits[:multiplier].max)
      denominator = solution.denominator
      denominator == 1 ? random.rand(limits[:multiplier].min..up_to) : denominator * random.rand(1..[ up_to / denominator, 1 ].max)
    end

    def plus(limits, random)
      x, a = random.rand(limits[:solution]), random.rand(limits[:addend])
      { a: a, b: x + a }
    end

    def minus(limits, random)
      x = random.rand([ limits[:solution].min, 2 ].max..limits[:solution].max)
      a = random.rand(1..[ x - 1, limits[:addend].max ].min)
      { a: a, b: x - a }
    end

    def divided(limits, random)
      { a: random.rand(limits[:divisor]), b: random.rand(limits[:solution]) }
    end

    def times(solution, limits, random)
      a = multiplier(solution, limits, random)
      { a: a, b: (a * solution).to_i }
    end

    def times_plus(solution, limits, random)
      a = multiplier(solution, limits, random)
      b = random.rand(limits[:addend])
      { a: a, b: b, c: (a * solution).to_i + b }
    end

    def times_minus(solution, limits, random)
      a = multiplier(solution, limits, random)
      a *= 2 while a * solution < 2
      product = (a * solution).to_i
      b = random.rand(1..[ product - 1, limits[:addend].max ].min)
      { a: a, b: b, c: product - b }
    end

    def divided_plus(limits, random)
      a, quotient, b = random.rand(limits[:divisor]), random.rand(1..10), random.rand(limits[:addend])
      { a: a, b: b, c: quotient + b }
    end

    def divided_minus(limits, random)
      a, quotient = random.rand(limits[:divisor]), random.rand(2..12)
      b = random.rand(1..[ quotient - 1, limits[:addend].max ].min)
      { a: a, b: b, c: quotient - b }
    end

    # Smaller numbers, as the bracket is already the hard part: 4(x + 2) = 30
    def bracket(solution, limits, random)
      a = multiplier(solution, limits, random, up_to: [ limits[:multiplier].max, 6 ].min)
      b = random.rand(1..6)
      { a: a, b: b, c: (a * (solution + b)).to_i }
    end

    def over(limits, random)
      b, c = random.rand(limits[:divisor]), random.rand(1..10)
      { a: random.rand(1..[ b * c - 1, limits[:addend].max ].min), b: b, c: c }
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
