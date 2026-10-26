# The sequences topic: five terms, and the next to find, by spotting the pattern. First linear (the same step each
# time, up or down), then quadratic (the step grows by the same each time, as square numbers do), then geometric
# (multiplying each time, or halving), then Fibonacci style (each term the two before added), then two-step (two
# steps taking turns). Every answer is a whole number, and every question has one answer: five terms are shown (5
# to 7 for two steps, so the next isn't always the first step), and a question that another kind of sequence would
# continue differently is never asked (Patternz, the daily challenge, mixes them all, so the kind has to be
# spotted too)
module Sequences
  TOPIC = "sequences"
  SLUG = "sequences"
  NAME = "Sequences"
  EMOJI = "🔢"
  SHOWN = 5
  # Two steps taking turns show a varied number of terms (n), so the next step could be either; 6 is most often
  TWO_STEP_SHOWN = [ 5, 6, 6, 7 ]

  # Each kind of sequence is a "fact": accuracy and speed are tracked per kind, and the weighting picks kinds.
  # a, b and c describe the sequence, as each kind says
  TYPES = {
    "add" => { difficulty: 0, form: "Going up", example: "3, 7, 11, 15, 19" },
    "subtract" => { difficulty: 0, form: "Going down", example: "50, 43, 36, 29, 22" },
    "square" => { difficulty: 1, form: "Square numbers", example: "2, 5, 10, 17, 26" },
    "quadratic" => { difficulty: 1, form: "Growing steps", example: "4, 6, 10, 16, 24" },
    "double" => { difficulty: 0, form: "Doubling", example: "3, 6, 12, 24, 48" },
    "times" => { difficulty: 1, form: "Multiplying", example: "2, 6, 18, 54, 162" },
    "halve" => { difficulty: 1, form: "Halving", example: "192, 96, 48, 24, 12" },
    "fibonacci" => { difficulty: 1, form: "Adding the two before", example: "2, 5, 7, 12, 19" },
    "alternate" => { difficulty: 2, form: "Two steps", example: "4, 9, 11, 16, 18" }
  }
  LEVELS = [
    { number: 1, name: "Linear", example: "3, 7, 11, 15, 19", types: %w[ add subtract ] },
    { number: 2, name: "Quadratic", example: "2, 5, 10, 17, 26", types: %w[ square quadratic ] },
    { number: 3, name: "Geometric", example: "3, 6, 12, 24, 48", types: %w[ double times halve ] },
    { number: 4, name: "Fibonacci style", example: "2, 5, 7, 12, 19", types: %w[ fibonacci ] },
    { number: 5, name: "Two-step", example: "4, 9, 11, 16, 18", types: %w[ alternate ] }
  ]
  # Multiplying stays under 100,000
  RATIOS = [ 3, 4, 5, 10 ]
  MOST = 100_000
  GEM_TIMES = { lightning: 3_000, quick: 6_000 }
  # A level's practice earns 1, 2 or 3 stars for how many it gets right; the first star unlocks the next level
  STARS = { 3 => 20, 2 => 10, 1 => 5 }
  BADGE_SCORES = [ 5, 10, 20, 30, 50 ]

  extend Topic::Playable
  extend self

  # Every answer is a whole number, so just the digits
  def keys(_level)
    []
  end

  # Facts: kinds of sequence. A level's practice asks only its own; mixed practice mixes in the ones before

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

  # One of the kind, made again until it has just the one answer
  def question(type, level: 1, random:)
    loop do
      question = { type: type, **numbers(type, random) }
      break worked(question) if possible?(question)
    end
  end

  # Works the answer out again from the numbers, so the score never depends on the browser. A question from this
  # level or an easier one (mixed practice mixes them), with numbers its kind could have used
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

  # "3, 7, 11, 15, 19, 23"
  def label(result)
    terms(question_from(result)).join(", ")
  end

  # Groups: each kind of sequence

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
    "Kind"
  end

  def rankable_group?(_type)
    true
  end

  def feedback_groups(level)
    groups(level)
  end

  def practise_message(types)
    "Practise sequences like #{types.map { |type| group_example(type) }.to_sentence}"
  end

  def summary(best:, needs:)
    [ "You're best at #{best.downcase}", ("and #{needs.downcase} needs the most practice" if needs) ].compact.join(", ") + "."
  end

  def value(question)
    terms(question).last
  end

  # How many are shown: five, or for two steps, as many as the question says
  def shown(question)
    question[:type] == "alternate" && question[:n].to_i.positive? ? question[:n].to_i : SHOWN
  end

  # The ones shown, then the next
  def terms(question)
    a, b, c = question.values_at(:a, :b, :c)
    count = shown(question) + 1
    case question[:type]
    when "add" then Array.new(count) { |i| a + b * i }
    when "subtract" then Array.new(count) { |i| a - b * i }
    when "square" then Array.new(count) { |i| (a + i)**2 + b }
    when "quadratic" then Array.new(count) { |i| a + b * i + c * i * (i - 1) / 2 }
    when "double" then Array.new(count) { |i| a * 2**i }
    when "times" then Array.new(count) { |i| a * b**i }
    when "halve" then Array.new(count) { |i| a / 2**i }
    when "fibonacci" then (count - 2).times.with_object([ a, b ]) { |_, list| list << list[-1] + list[-2] }
    when "alternate" then (count - 1).times.with_object([ a ]) { |i, list| list << list.last + (i.even? ? b : c) }
    end
  end

  private
    def level_details(number)
      level(number) || raise(Attempt::Invalid, "Unknown level")
    end

    def question_from(result)
      type = result["type"]
      raise Attempt::Invalid, "Bad question" unless TYPES.key?(type)

      a, b, c, n = result.values_at("a", "b", "c", "n").map { |number| number.nil? ? 0 : Integer(number, exception: false) }
      raise Attempt::Invalid, "Bad question" unless a && b && c && n

      { type: type, a: a, b: b, c: c, n: (n if n.positive?) }.compact
    end

    # Numbers its kind could use, before checking it has one answer
    def numbers(type, random)
      pick = ->(range) { range.to_a.sample(random: random) }
      case type
      when "add" then { a: pick[1..20], b: pick[2..12], c: 0 }
      when "subtract" then { b: (step = pick[2..12]), a: step * SHOWN + pick[1..30], c: 0 }
      when "square" then { a: pick[1..8], b: pick[0..12], c: 0 }
      when "quadratic" then { a: pick[1..15], b: pick[1..8], c: pick[2..5] }
      when "double" then { a: pick[1..15], b: 0, c: 0 }
      when "times" then { b: (ratio = RATIOS.sample(random: random)), a: pick[1..(MOST / ratio**SHOWN).clamp(1, 5)], c: 0 }
      when "halve" then { a: 2**SHOWN * pick[1..9], b: 0, c: 0 }
      when "fibonacci" then { a: pick[1..9], b: pick[1..12], c: 0 }
      when "alternate" then { a: pick[1..20], b: pick[1..12], c: pick[-6..12], n: TWO_STEP_SHOWN.sample(random: random) }
      end
    end

    # Numbers its kind could have used, giving whole, positive terms, and only one answer
    def possible?(question)
      a, b, c = question.values_at(:a, :b, :c)
      fits = case question[:type]
      when "add" then a.between?(1, 20) && b.between?(2, 12) && c.zero?
      when "subtract" then b.between?(2, 12) && a.between?(b * SHOWN + 1, b * SHOWN + 30) && c.zero?
      when "square" then a.between?(1, 8) && b.between?(0, 12) && c.zero?
      when "quadratic" then a.between?(1, 15) && b.between?(1, 8) && c.between?(2, 5)
      when "double" then a.between?(1, 15) && b.zero? && c.zero?
      when "times" then RATIOS.include?(b) && a.between?(1, 5) && a * b**SHOWN <= MOST && c.zero?
      when "halve" then (a % 2**SHOWN).zero? && (a / 2**SHOWN).between?(1, 9) && b.zero? && c.zero?
      when "fibonacci" then a.between?(1, 9) && b.between?(1, 12) && c.zero?
      when "alternate" then a.between?(1, 20) && b.between?(1, 12) && c.between?(-6, 12) && !c.zero? && c != b && (question[:n].to_i.zero? || TWO_STEP_SHOWN.include?(question[:n]))
      end
      fits &&= question[:n].to_i.zero? || question[:type] == "alternate"
      fits && (terms = terms(question)).all?(&:positive?) && one_answer?(terms.first(shown(question)), terms.last)
    end

    # Every kind of sequence the shown terms fit continues them the same way
    def one_answer?(shown, answer)
      next_terms(shown).all?(answer)
    end

    # What each kind of sequence the terms fit would come next: steps that grow evenly (linear ones don't grow at
    # all), a ratio, adding the two before, and two steps taking turns
    def next_terms(shown)
      steps = shown.each_cons(2).map { |first, second| second - first }
      growth = steps.each_cons(2).map { |first, second| second - first }
      ratios = shown.each_cons(2).map { |first, second| Rational(second, first) }
      [
        (shown.last + steps.last + growth.last if growth.uniq.one?),
        (shown.last * ratios.last if ratios.uniq.one? && (shown.last * ratios.last).denominator == 1),
        (shown[-1] + shown[-2] if (2...shown.size).all? { |i| shown[i] == shown[i - 1] + shown[i - 2] }),
        (shown.last + steps[-2] if steps.each_slice(2).map(&:first).uniq.one? && steps.each_slice(2).filter_map(&:second).uniq.one?)
      ].compact
    end

    def written(question)
      "#{terms(question).first(shown(question)).join(", ")}, …"
    end
end
