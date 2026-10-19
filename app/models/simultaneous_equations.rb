# The simultaneous equations topic: two equations, ax + by = c and dx + ey = f, lined up one under the other.
# The y terms cancel when the equations are subtracted or added (after doubling one, at the top level), so
# x comes first; then the same pair is asked again, with x given, for y. At level 1 subtracting leaves x
# itself: 3x + 5y = 11 take away 2x + 5y = 9 is x = 2.
#
# Everything is meant to be worked out in your head: solutions are 1 to 5 and the totals stay small, so
# there's no minus key. Each way of solving is a "fact". A question is one of the two answers, marked by
# v ("x" or "y")
module SimultaneousEquations
  TOPIC = "simultaneous"
  SLUG = "simultaneous-equations"
  NAME = "Simultaneous equations"
  # Two equations linked together
  EMOJI = "🔗"

  TYPES = {
    "subtract"            => { difficulty: 0, form: "Subtract",            example: "3x + 5y = 11, 2x + 5y = 9" },
    "subtract and divide" => { difficulty: 1, form: "Subtract and divide", example: "5x + 2y = 16, 2x + 2y = 10" },
    "add"                 => { difficulty: 1, form: "Add",                 example: "2x + 3y = 13, x − 3y = −7" },
    "multiply"            => { difficulty: 2, form: "Double one",          example: "x + y = 5, 3x + 2y = 12" }
  }

  # Each level adds to the one before. Levels 1 and 2 are all positive; from level 4 terms can be negative,
  # and either equation can come first
  LEVELS = [
    { number: 1, name: "Subtract", example: "3x + 5y = 11, 2x + 5y = 9", types: %w[ subtract ], negatives: false, max_total: 20 },
    { number: 2, name: "Subtract and divide", example: "5x + 2y = 16, 2x + 2y = 10", types: [ "subtract", "subtract and divide" ], negatives: false, max_total: 20 },
    { number: 3, name: "Add", example: "2x + 3y = 13, x − 3y = −7", types: [ "subtract", "subtract and divide", "add" ], negatives: false, max_total: 20 },
    { number: 4, name: "Mixed", example: "3x − 2y = 5, x − 2y = −1", types: [ "subtract", "subtract and divide", "add" ], negatives: true, max_total: 25 },
    { number: 5, name: "Double one", example: "x + y = 5, 3x + 2y = 12", types: [ "subtract", "subtract and divide", "add", "multiply" ], negatives: true, max_total: 25 }
  ]
  # Quick and lightning stars: each answer is a few steps of working out
  STAR_TIMES = { lightning: 5_000, quick: 10_000 }
  # A level's practice earns a medal for its score; bronze unlocks the next level
  MEDALS = { gold: 20, silver: 10, bronze: 5 }
  # Scores in one game that earn a badge. Lower than the other topics: each pair of equations is two answers
  BADGE_SCORES = [ 5, 10, 15, 20, 30 ]
  SOLUTIONS = 1..5
  UNKNOWNS = %w[ x y ]
  MAX_NUMBER = 999

  extend Topic::Playable
  extend self

  def keys(_level)
    []
  end

  # Facts: ways of solving

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

  # Each pair of equations is asked twice in a row: first for x, then, with x given, for y
  def questions_for(type, level: 1, random:)
    pair = build(type, level_details(level), random)
    UNKNOWNS.map { |unknown| ask(pair.merge(v: unknown)) }
  end

  # A question written and answered as the game would: a lesson's one to try (the pair, asking for x) or one
  # asked again in a review (for whichever it asked)
  def worked(pair)
    ask({ v: "x", **pair })
  end

  # Solves the pair again from its numbers, so the score never depends on the browser. The way of solving
  # must be one the level asks, and must be how this pair's y terms cancel
  def clean_result(result, level: 1)
    question = question_from(result)
    raise Attempt::Invalid, "Bad question" unless facts(level).include?(question[:type]) && way_of_solving(question) == question[:type]

    given = result["given"].to_s
    raise Attempt::Invalid, "Bad answer" unless given.match?(Attempt::TYPED_ANSWER)

    question.transform_keys(&:to_s).merge("given" => given, "correct" => given == solution(question).fetch(question[:v]).to_s)
  end

  # "3x + 5y = 11 and 2x + 5y = 9, so x = 2". Read as it was saved, so games from before the levels changed
  # still show on their results pages
  def label(result)
    question = { **%w[ a b c d e f ].to_h { |key| [ key.to_sym, Integer(result[key], exception: false) || 0 ] }, v: result["v"] }
    first, second = equations(question, plain_style)
    "#{first} and #{second}, so #{question[:v]} = #{solution(question).fetch(question[:v])}"
  end

  # Groups: each way of solving

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
    "Method"
  end

  def rankable_group?(_type)
    true
  end

  def feedback_groups(level)
    groups(level)
  end

  def practise_message(types)
    "Practise simultaneous equations like #{types.map { |type| group_example(type) }.to_sentence}"
  end

  def summary(best:, needs:)
    [ "Your best method is #{best.downcase}", ("and #{needs.downcase} needs the most practice" if needs) ].compact.join(", ") + "."
  end

  # { "x" => 2, "y" => 1 }, worked out from the equations alone
  def solution(question)
    a, b, c, d, e, f = question.values_at(:a, :b, :c, :d, :e, :f)
    determinant = a * e - b * d
    { "x" => Rational(c * e - b * f, determinant), "y" => Rational(a * f - c * d, determinant) }.transform_values(&:to_i)
  end

  private
    def level_details(number)
      level(number) || raise(Attempt::Invalid, "Unknown level")
    end

    # Questions: the solution is chosen first and the equations built around it, again until the totals
    # are small enough for the level

    def ask(question)
      question.merge(text: html(question), answer: solution(question).fetch(question[:v]).to_s)
    end

    def build(type, details, random)
      loop do
        x, y = random.rand(SOLUTIONS), random.rand(SOLUTIONS)
        a, b, d, e = coefficients(type, details, random)
        pair = { type: type, a: a, b: b, c: a * x + b * y, d: d, e: e, f: d * x + e * y }
        pair = swapped(pair) if details[:negatives] && random.rand < 0.5
        return pair if fits?(pair, details)
      end
    end

    def coefficients(type, details, random)
      y_terms = details[:negatives] ? [ *-3..-1, *1..5 ] : [ *1..5 ]

      case type
      when "subtract", "subtract and divide"
        # The same y term, and x terms 1 apart (so x is left) or 2 or 3 apart (so 2x or 3x is)
        d, b = random.rand(1..3), y_terms.sample(random: random)
        [ d + (type == "subtract" ? 1 : random.rand(2..3)), b, d, b ]
      when "add"
        b = random.rand(1..4)
        [ random.rand(1..3), b, random.rand(1..2), -b ]
      when "multiply"
        b = random.rand(1..2)
        [ random.rand(1..3), b, random.rand(1..5), 2 * b * [ 1, -1 ].sample(random: random) ]
      end
    end

    # Small totals, positive at levels without negatives (adding always has one negative), and solved the
    # way the type says
    def fits?(pair, details)
      totals = pair.values_at(:c, :f)
      totals.all? { |total| total.nonzero? && total.abs <= details[:max_total] } &&
        (details[:negatives] || pair[:type] == "add" || totals.all?(&:positive?)) &&
        way_of_solving(pair) == pair[:type] && doubled_x_term_small?(pair)
    end

    # Doubling the equation with the smaller y term, then cancelling y, leaves at most 4x, so dividing is easy
    def doubled_x_term_small?(pair)
      return true unless pair[:type] == "multiply"

      a, b, d, e = pair.values_at(:a, :b, :d, :e)
      a, b, d, e = d, e, a, b if b.abs > e.abs
      left = 2 * b == e ? 2 * a - d : 2 * a + d
      (1..4).cover?(left.abs)
    end

    # Either equation can come first
    def swapped(pair)
      pair.merge(a: pair[:d], b: pair[:e], c: pair[:f], d: pair[:a], e: pair[:b], f: pair[:c])
    end

    # How the y terms cancel, from the coefficients alone
    def way_of_solving(question)
      a, b, d, e = question.values_at(:a, :b, :d, :e)

      if b == e then (a - d).abs == 1 ? "subtract" : "subtract and divide"
      elsif b == -e then "add"
      elsif e.abs == 2 * b.abs || b.abs == 2 * e.abs then "multiply"
      end
    end

    # Checking a pair sent back: whole numbers, a single whole solution from 1 to 5, and x or y asked

    def question_from(result)
      type = result["type"]
      raise Attempt::Invalid, "Bad question" unless TYPES.key?(type) && UNKNOWNS.include?(result["v"])

      numbers = %w[ a b c d e f ].to_h { |key| [ key.to_sym, Integer(result[key], exception: false) ] }
      raise Attempt::Invalid, "Bad question" unless numbers.values.all? { |number| number && number.abs <= MAX_NUMBER }
      raise Attempt::Invalid, "Bad question" unless numbers.values_at(:a, :b, :d, :e).all?(&:nonzero?) && solvable?(numbers)

      { type: type, **numbers, v: result["v"] }
    end

    def solvable?(numbers)
      a, b, c, d, e, f = numbers.values_at(:a, :b, :c, :d, :e, :f)
      determinant = a * e - b * d
      determinant.nonzero? && ((c * e - b * f) % determinant).zero? && ((a * f - c * d) % determinant).zero? &&
        solution(numbers).values.all? { |value| SOLUTIONS.cover?(value) }
    end

    # Written out: for the game lined up in columns, for the results page on one line

    Style = Data.define(:letter, :row)

    def html_style
      Style.new(letter: ->(name) { "<var>#{name}</var>" },
        row: ->(cells) { %(<span class="system__row">#{cells.map { |cell| "<span>#{cell}</span>" }.join}</span>) })
    end

    def plain_style
      Style.new(letter: ->(name) { name }, row: ->(cells) { cells.join(" ") })
    end

    # The two equations in columns (x term, sign, y term, =, total), then what's asked: x =, or x given then y =
    def html(question)
      style = html_style
      system = %(<span class="system">#{equations(question, style).join}</span>)
      known = (%(<span class="system__known"><var>x</var> = #{solution(question).fetch("x")}</span>) if question[:v] == "y")
      [ system, known, %(<span class="system__ask"><var>#{question[:v]}</var> =</span>) ].compact.join
    end

    def equations(question, style)
      a, b, c, d, e, f = question.values_at(:a, :b, :c, :d, :e, :f)
      [ [ a, b, c ], [ d, e, f ] ].map do |x_coefficient, y_coefficient, total|
        style.row.([ term(x_coefficient, style.letter.("x")), y_coefficient.negative? ? "−" : "+",
          term(y_coefficient.abs, style.letter.("y")), "=", number(total) ])
      end
    end

    # 2x, x, −2x, −x
    def term(coefficient, letter)
      "#{"−" if coefficient.negative?}#{coefficient.abs unless coefficient.abs == 1}#{letter}"
    end

    def number(value)
      value.negative? ? "−#{value.abs}" : value.to_s
    end
end
