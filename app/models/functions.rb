# The functions topic: given a function like f(x) = 2x + 3, work out f(4). Harder levels bring negative
# inputs, squares, composite functions like f(g(5)), and inverses like f⁻¹(11). Every answer is a whole number.
#
# The input is n, the function's numbers are a and b, and a second function g(x) = cx + d has c and d.
# In single functions the sign is part of the type (ax − b); in composites and inverses b and d carry their own
module Functions
  TOPIC = "functions"
  SLUG = "functions"
  NAME = "Functions"
  # A function machine
  EMOJI = "⚙️"

  # Each form of function is a "fact": accuracy and speed are tracked per form, and the weighting picks forms
  TYPES = {
    "x+a"       => { difficulty: 0, form: "x + a",            example: "f(x) = x + 5" },
    "x-a"       => { difficulty: 0, form: "x − a",            example: "f(x) = x − 3" },
    "ax"        => { difficulty: 0, form: "ax",               example: "f(x) = 4x" },
    "ax+b"      => { difficulty: 1, form: "ax + b",           example: "f(x) = 2x + 3" },
    "ax-b"      => { difficulty: 1, form: "ax − b",           example: "f(x) = 3x − 1" },
    "x/a+b"     => { difficulty: 1, form: "x/a + b",          example: "f(x) = x/2 + 5" },
    "x^2+a"     => { difficulty: 1, form: "x² + a",           example: "f(x) = x² + 4" },
    "x^2-a"     => { difficulty: 1, form: "x² − a",           example: "f(x) = x² − 5" },
    "ax^2"      => { difficulty: 2, form: "ax²",              example: "f(x) = 3x²" },
    "(x+a)^2"   => { difficulty: 2, form: "(x + a)²",         example: "f(x) = (x + 2)²" },
    "f(g(x))"   => { difficulty: 2, form: "f(g(x))",          example: "f(g(5))" },
    "g(f(x))"   => { difficulty: 2, form: "g(f(x))",          example: "g(f(5))" },
    "inv:ax+b"  => { difficulty: 2, form: "f⁻¹(x), ax + b",   example: "f⁻¹(11) when f(x) = 2x + 3" },
    "inv:x/a+b" => { difficulty: 2, form: "f⁻¹(x), x/a + b",  example: "f⁻¹(7) when f(x) = x/2 + 3" }
  }
  LINEAR = %w[ x+a x-a ax ax+b ax-b ]
  DIVIDED = %w[ x/a+b ]
  SQUARES = %w[ x^2+a x^2-a ax^2 (x+a)^2 ]
  COMPOSITE = %w[ f(g(x)) g(f(x)) ]
  INVERSE = %w[ inv:ax+b inv:x/a+b ]

  # Each level adds to the one before, so earlier levels' questions are always fair game.
  # Level 1 keeps everything positive, so there's no minus key until level 2
  SMALL = { input: 1..10, multiplier: 2..5, addend: 1..10 }
  BIG = { input: -10..10, multiplier: 2..10, addend: 1..20 }
  LEVELS = [
    { number: 1, name: "Linear", example: "f(x) = 2x + 3", types: LINEAR, limits: SMALL, negatives: false },
    { number: 2, name: "Negatives", example: "f(−4)", types: LINEAR + DIVIDED, limits: BIG, negatives: true },
    { number: 3, name: "Squares", example: "f(x) = x² − 5", types: LINEAR + DIVIDED + SQUARES, limits: BIG, negatives: true },
    { number: 4, name: "Composite", example: "f(g(5))", types: LINEAR + DIVIDED + SQUARES + COMPOSITE, limits: BIG, negatives: true },
    { number: 5, name: "Inverse", example: "f⁻¹(11)", types: LINEAR + DIVIDED + SQUARES + COMPOSITE + INVERSE, limits: BIG, negatives: true }
  ]
  # Quick and lightning stars, allowing for working out a function taking longer than a times table
  STAR_TIMES = { lightning: 3_000, quick: 6_000 }
  # Scores in one game that earn a badge. Like equations: each question takes some reading
  BADGE_SCORES = [ 5, 10, 20, 30, 50 ]
  # The largest number the server accepts in a question sent back (well above anything generated)
  MAX_NUMBER = 999
  ANSWER_FORMAT = /\A-?\d{1,6}\z/

  extend Topic::Playable
  extend self

  # Extra keypad keys beyond the digits: a minus sign once answers can be negative
  def keys(level)
    level_details(level)[:negatives] ? [ "-" ] : []
  end

  # Facts: forms of function

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
    question = { type: type, **build(type, level_details(level), random) }
    question.merge(text: html(question), answer: value(question).to_s)
  end

  # Works the answer out again from the numbers, so the score never depends on the browser.
  # A question from this level or an easier one: its form must be in the level, and negatives only from level 2
  def clean_result(result, level: 1)
    question = question_from(result)
    raise Attempt::Invalid, "Bad question" unless facts(level).include?(question[:type]) && possible?(question)
    raise Attempt::Invalid, "Bad question" unless level_details(level)[:negatives] || (question.values_at(*numbers_used(question[:type])) + [ value(question) ]).all?(&:positive?)

    given = result["given"].to_s
    raise Attempt::Invalid, "Bad answer" unless given.match?(ANSWER_FORMAT)

    question.transform_keys(&:to_s).merge("given" => given, "correct" => given == value(question).to_s)
  end

  # "f(x) = 2x + 3, so f(4) = 11"
  def label(result)
    question = question_from(result)
    "#{written(question, plain_style)}, so #{asked(question, plain_style)} = #{number(value(question))}"
  end

  # Groups: each form of function

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
    "Practise functions like #{types.map { |type| group_example(type) }.to_sentence}"
  end

  def summary(best:, needs:)
    [ "You're best at functions like #{best}", ("and functions like #{needs} need the most practice" if needs) ].compact.join(", ") + "."
  end

  def value(question)
    a, b, c, d, n = question.values_at(:a, :b, :c, :d, :n)

    case question[:type]
    when "x+a"       then n + a
    when "x-a"       then n - a
    when "ax"        then a * n
    when "ax+b"      then a * n + b
    when "ax-b"      then a * n - b
    when "x/a+b"     then n / a + b
    when "x^2+a"     then n**2 + a
    when "x^2-a"     then n**2 - a
    when "ax^2"      then a * n**2
    when "(x+a)^2"   then (n + a)**2
    when "f(g(x))"   then a * (c * n + d) + b
    when "g(f(x))"   then c * (a * n + b) + d
    when "inv:ax+b"  then (n - b) / a
    when "inv:x/a+b" then a * (n - b)
    end
  end

  private
    def level_details(number)
      level(number) || raise(Attempt::Invalid, "Unknown level")
    end

    # Questions

    def build(type, details, random)
      limits = details[:limits]

      case type
      when "x+a"               then { a: random.rand(limits[:addend]), n: input(limits, random) }
      when "x-a"               then minus(details, random)
      when "ax"                then { a: random.rand(limits[:multiplier]), n: input(limits, random) }
      when "ax+b"              then { a: random.rand(limits[:multiplier]), b: random.rand(limits[:addend]), n: input(limits, random) }
      when "ax-b"              then times_minus(details, random)
      when "x/a+b"             then divided(random)
      when "x^2+a", "x^2-a"    then { a: random.rand(1..20), n: nonzero(-6..6, random) }
      when "ax^2"              then { a: random.rand(2..5), n: nonzero(-5..5, random) }
      when "(x+a)^2"           then { a: random.rand(1..6), n: nonzero(-8..8, random) }
      when "f(g(x))", "g(f(x))" then composite(random)
      when "inv:ax+b"          then inverse_linear(random)
      when "inv:x/a+b"         then inverse_divided(random)
      end
    end

    # Negative inputs from level 2; never 0, which makes too many questions trivial
    def input(limits, random)
      nonzero(limits[:input], random)
    end

    def nonzero(range, random)
      number = random.rand(range) until number&.nonzero?
      number
    end

    def signed(range, random)
      nonzero(-range.max..range.max, random)
    end

    # At level 1 the answer stays positive
    def minus(details, random)
      limits = details[:limits]
      return { a: random.rand(limits[:addend]), n: input(limits, random) } if details[:negatives]

      n = random.rand(2..limits[:input].max)
      { a: random.rand(1..[ n - 1, limits[:addend].max ].min), n: n }
    end

    def times_minus(details, random)
      limits = details[:limits]
      a, n = random.rand(limits[:multiplier]), input(limits, random)
      b = details[:negatives] ? random.rand(limits[:addend]) : random.rand(1..[ a * n - 1, limits[:addend].max ].min)
      { a: a, b: b, n: n }
    end

    # The input is a multiple of a, so x/a is whole
    def divided(random)
      a = random.rand(2..5)
      { a: a, b: random.rand(1..20), n: a * nonzero(-10..10, random) }
    end

    # f(x) = ax + b and g(x) = cx + d, kept small: it's two steps in your head
    def composite(random)
      { a: random.rand(1..5), b: signed(1..9, random), c: random.rand(1..5), d: signed(1..9, random), n: nonzero(-5..5, random) }
    end

    # Built from the answer, so f⁻¹(n) is whole
    def inverse_linear(random)
      a, b = random.rand(2..6), signed(1..10, random)
      { a: a, b: b, n: a * nonzero(-10..10, random) + b }
    end

    def inverse_divided(random)
      a, b = random.rand(2..5), signed(1..10, random)
      { a: a, b: b, n: nonzero(-10..10, random) + b }
    end

    # Checking a question sent back

    def question_from(result)
      type = result["type"]
      raise Attempt::Invalid, "Bad question" unless TYPES.key?(type)

      numbers = %w[ a b c d n ].to_h { |key| [ key.to_sym, Integer(result[key], exception: false) ] }.slice(*numbers_used(type))
      raise Attempt::Invalid, "Bad question" unless numbers.values.all? { |number| number&.abs&.<=(MAX_NUMBER) }

      { type: type, **numbers }
    end

    def numbers_used(type)
      case type
      when "x+a", "x-a", "ax", "x^2+a", "x^2-a", "ax^2", "(x+a)^2" then %i[ a n ]
      when "f(g(x))", "g(f(x))"                                then %i[ a b c d n ]
      else %i[ a b n ]
      end
    end

    # Numbers the game could have used: multipliers and divisors above 0, constants with their sign in the
    # type positive, and divisions that come out whole
    def possible?(question)
      a, b, c, n = question.values_at(:a, :b, :c, :n)

      case question[:type]
      when "f(g(x))", "g(f(x))" then a.positive? && c.positive?
      when "inv:ax+b"           then a > 1 && ((n - b) % a).zero?
      when "inv:x/a+b"          then a > 1
      when "x/a+b"              then a > 1 && b.positive? && (n % a).zero?
      else a.positive? && (b.nil? || b.positive?)
      end
    end

    # Written out: for the game in HTML, with the letters in italics and x/a stacked; for the results page plainly

    Style = Data.define(:letter, :over)

    def html_style
      Style.new(letter: ->(name) { "<var>#{name}</var>" },
        over: ->(top, bottom) { %(<span class="frac"><span>#{top}</span><span>#{bottom}</span></span>) })
    end

    def plain_style
      Style.new(letter: ->(name) { name }, over: ->(top, bottom) { "#{top}/#{bottom}" })
    end

    # Each function on its own line, then what's asked: f(x) = 2x + 1 / g(x) = x − 3 / f(g(5))
    def html(question)
      style = html_style
      lines = definitions(question, style).map { |definition| %(<span class="function">#{definition}</span>) }
      [ *lines, %(<span class="function function--ask">#{asked(question, style)}</span>) ].join
    end

    def written(question, style)
      definitions(question, style).join(" and ")
    end

    def definitions(question, style)
      composite = COMPOSITE.include?(question[:type])
      [ "#{call("f", style.letter.("x"), style)} = #{rule(question, style)}",
        ("#{call("g", style.letter.("x"), style)} = #{linear(question[:c], question[:d], style)}" if composite) ].compact
    end

    def asked(question, style)
      n = number(question[:n])

      case question[:type]
      when "f(g(x))" then call("f", call("g", n, style), style)
      when "g(f(x))" then call("g", call("f", n, style), style)
      when "inv:ax+b", "inv:x/a+b" then "#{style.letter.("f")}⁻¹(#{n})"
      else call("f", n, style)
      end
    end

    def call(name, argument, style)
      "#{style.letter.(name)}(#{argument})"
    end

    # The right hand side of f(x) = …
    def rule(question, style)
      a, b = question.values_at(:a, :b)
      x = style.letter.("x")

      case question[:type]
      when "x+a"                then "#{x} + #{a}"
      when "x-a"                then "#{x} − #{a}"
      when "ax"                 then "#{a}#{x}"
      when "ax+b"               then "#{a}#{x} + #{b}"
      when "ax-b"               then "#{a}#{x} − #{b}"
      when "x/a+b"              then "#{style.over.(x, a)} + #{b}"
      when "x^2+a"              then "#{x}² + #{a}"
      when "x^2-a"              then "#{x}² − #{a}"
      when "ax^2"               then "#{a}#{x}²"
      when "(x+a)^2"            then "(#{x} + #{a})²"
      when "f(g(x))", "g(f(x))", "inv:ax+b" then linear(a, b, style)
      when "inv:x/a+b"          then "#{style.over.(x, a)}#{constant(b)}"
      end
    end

    # 2x + 3, x − 4: a multiplier of 1 isn't written, and the constant's sign is shown as + or −
    def linear(multiplier, addend, style)
      "#{multiplier unless multiplier == 1}#{style.letter.("x")}#{constant(addend)}"
    end

    def constant(number)
      number.negative? ? " − #{number.abs}" : " + #{number}"
    end

    # With a proper minus sign: −4
    def number(value)
      value.negative? ? "−#{value.abs}" : value.to_s
    end
end
