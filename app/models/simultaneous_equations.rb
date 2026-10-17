# The simultaneous equations topic: two equations, ax + by = c and dx + ey = f, lined up one under the other.
# The x terms are made to cancel when the equations are added or subtracted (after multiplying, at the top
# levels), so y comes first; then the same pair is asked again, with y given, for x.
# Every system has a whole number solution from 1 to 9, so there's no minus key.
#
# Each way of solving is a "fact": subtracting, adding, multiplying one equation, multiplying both.
# A question is one of the two answers, marked by v ("y" or "x")
module SimultaneousEquations
  TOPIC = "simultaneous"
  SLUG = "simultaneous-equations"
  NAME = "Simultaneous equations"
  # Two equations linked together
  EMOJI = "🔗"

  TYPES = {
    "subtract"      => { difficulty: 0, form: "Subtract",      example: "2x + 3y = 13, 2x + y = 7" },
    "add"           => { difficulty: 1, form: "Add",           example: "2x + 3y = 13, −2x + y = −1" },
    "multiply one"  => { difficulty: 1, form: "Multiply one",  example: "2x + 3y = 12, 4x + y = 14" },
    "multiply both" => { difficulty: 2, form: "Multiply both", example: "2x + 5y = 16, 3x + 2y = 13" }
  }

  # Each level adds to the one before. Level 1 is all positive: matching x terms, so subtract.
  # Level 3 mixes adding and subtracting, and some y terms are negative. Once equations need multiplying,
  # the solutions are smaller, so the multiplied totals can still be worked out in your head
  LEVELS = [
    { number: 1, name: "Subtract", example: "2x + 3y = 13, 2x + y = 7", types: %w[ subtract ], negative_y: false, solutions: 1..9 },
    { number: 2, name: "Add", example: "2x + 3y = 13, −2x + y = −1", types: %w[ subtract add ], negative_y: false, solutions: 1..9 },
    { number: 3, name: "Mixed", example: "3x − 2y = 5, 3x + y = 11", types: %w[ subtract add ], negative_y: true, solutions: 1..9 },
    { number: 4, name: "Multiply one", example: "2x + 3y = 12, 4x + y = 14", types: %w[ subtract add multiply\ one ], negative_y: true, solutions: 1..6 },
    { number: 5, name: "Multiply both", example: "2x + 5y = 16, 3x + 2y = 13", types: %w[ subtract add multiply\ one multiply\ both ], negative_y: true, solutions: 1..6 }
  ]
  # Scores in one game that earn a badge. Lower than the other topics: each pair of equations is two answers,
  # and takes some working out
  BADGE_SCORES = [ 5, 10, 15, 20, 30 ]
  # Every level's solutions are in here
  SOLUTIONS = 1..9
  # x coefficients that both need multiplying to match, kept to what can be done in your head
  BOTH_MULTIPLIED = [ [ 2, 3 ], [ 3, 2 ], [ 2, 5 ], [ 3, 4 ], [ 4, 3 ] ]
  UNKNOWNS = %w[ y x ]
  MAX_NUMBER = 999
  ANSWER_FORMAT = /\A-?\d{1,4}\z/

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

  # Each pair of equations is asked twice in a row: first for y, then, with y given, for x
  def questions_for(type, level: 1, random:)
    system = build(type, level_details(level), random)
    UNKNOWNS.map { |unknown| ask(system.merge(v: unknown)) }
  end

  # Solves the pair again from its numbers, so the score never depends on the browser. The way of solving
  # must be one the level asks, and must be how this pair's x terms are made to cancel
  def clean_result(result, level: 1)
    question = question_from(result)
    raise Attempt::Invalid, "Bad question" unless facts(level).include?(question[:type]) && way_of_solving(question) == question[:type]

    given = result["given"].to_s
    raise Attempt::Invalid, "Bad answer" unless given.match?(ANSWER_FORMAT)

    question.transform_keys(&:to_s).merge("given" => given, "correct" => given == solution(question).fetch(question[:v]).to_s)
  end

  # "2x + 3y = 13 and 2x + y = 7, so y = 3"
  def label(result)
    question = question_from(result)
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
    "Practise simultaneous equations where you #{types.map { |type| group_label(type).downcase }.to_sentence}"
  end

  def summary(best:, needs:)
    [ "You're best at simultaneous equations where you #{best.downcase}", ("and ones where you #{needs.downcase} need the most practice" if needs) ].compact.join(", ") + "."
  end

  # { "x" => 2, "y" => 3 }, worked out from the equations alone
  def solution(question)
    a, b, c, d, e, f = question.values_at(:a, :b, :c, :d, :e, :f)
    determinant = a * e - b * d
    { "x" => Rational(c * e - b * f, determinant), "y" => Rational(a * f - c * d, determinant) }.transform_values(&:to_i)
  end

  private
    def level_details(number)
      level(number) || raise(Attempt::Invalid, "Unknown level")
    end

    # Questions: the solution is chosen first, and the equations built around it

    def ask(question)
      question.merge(text: html(question), answer: solution(question).fetch(question[:v]).to_s)
    end

    def build(type, details, random)
      x, y = random.rand(details[:solutions]), random.rand(details[:solutions])
      a, d = x_coefficients(type, random)
      b, e = y_coefficients(type, a, d, details, random)
      first, second = { a: a, b: b, c: a * x + b * y }, { d: d, e: e, f: d * x + e * y }
      rows = first.merge(second)
      rows = swapped(rows) if type == "multiply one" && random.rand < 0.5
      { type: type, **rows }
    end

    def x_coefficients(type, random)
      case type
      when "subtract"      then [ random.rand(1..5) ] * 2
      when "add"           then random.rand(1..5).then { |a| [ a, -a ] }
      when "multiply one"  then random.rand(1..3).then { |a| [ a, a * random.rand(2..3) * [ 1, -1 ].sample(random: random) ] }
      when "multiply both" then BOTH_MULTIPLIED.sample(random: random)
      end
    end

    # Small, and never leaving nothing once the x terms cancel
    def y_coefficients(type, a, d, details, random)
      range = details[:negative_y] && type != "multiply both" ? [ *-4..-1, *1..6 ] : [ *1..6 ]
      range = [ *1..4 ] if type == "multiply both"

      loop do
        b, e = range.sample(random: random), range.sample(random: random)
        return [ b, e ] if a * e - b * d != 0 && (type != "subtract" || b != e)
      end
    end

    # The multiplied equation can be either one
    def swapped(rows)
      { a: rows[:d], b: rows[:e], c: rows[:f], d: rows[:a], e: rows[:b], f: rows[:c] }
    end

    # How the x terms are made to cancel, from the coefficients alone
    def way_of_solving(question)
      a, d = question.values_at(:a, :d)

      if a == d then "subtract"
      elsif a == -d then "add"
      elsif (d % a).zero? || (a % d).zero? then "multiply one"
      else "multiply both"
      end
    end

    # Checking a pair sent back: whole numbers, a single whole solution from 1 to 9, and y or x asked

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

    # The two equations in columns (x term, sign, y term, =, total), then what's asked: y =, or y given then x =
    def html(question)
      style = html_style
      system = %(<span class="system">#{equations(question, style).join}</span>)
      known = (%(<span class="system__known"><var>y</var> = #{solution(question).fetch("y")}</span>) if question[:v] == "x")
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
