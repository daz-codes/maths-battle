# The metric conversions topic: changing between units of length, then mass, then volume, like 250 cm = 2.5 m.
# Each pair of units is a fact, either way round (cm to m and m to cm are two), so the weighting finds the ones a
# player finds hard. Numbers are tidy: at most two decimal places in the bigger unit, so the smaller is whole
require "bigdecimal"

module Conversions
  TOPIC = "conversions"
  SLUG = "metric-conversions"
  NAME = "Metric conversions"
  EMOJI = "📏"

  # How many of the smaller unit make one of the bigger
  UNITS = {
    "mm-cm" => 10, "cm-m" => 100, "mm-m" => 1_000, "m-km" => 1_000,
    "mg-g" => 1_000, "g-kg" => 1_000,
    "ml-l" => 1_000, "l-kl" => 1_000
  }
  LENGTH = %w[ mm-cm cm-m mm-m m-km ]
  MASS = %w[ mg-g g-kg ]
  VOLUME = %w[ ml-l l-kl ]

  # Each fact is a pair of units one way round: "cm>m" is cm to m, "m>cm" is m to cm
  def self.both_ways(pairs)
    pairs.flat_map { |pair| small, big = pair.split("-"); [ "#{small}>#{big}", "#{big}>#{small}" ] }
  end

  LEVELS = [
    { number: 1, name: "cm and m", example: "250 cm = ? m", types: both_ways(%w[ cm-m ]) },
    { number: 2, name: "Length", example: "3.5 km = ? m", types: both_ways(LENGTH) },
    { number: 3, name: "Mass", example: "1.2 kg = ? g", types: both_ways(MASS) },
    { number: 4, name: "Volume", example: "750 ml = ? l", types: both_ways(VOLUME) },
    { number: 5, name: "Mixed", example: "45 mm = ? cm", types: both_ways(LENGTH + MASS + VOLUME) }
  ]
  STAR_TIMES = { lightning: 3_000, quick: 6_000 }
  # A level's practice earns a medal for its score; bronze unlocks the next level
  MEDALS = { gold: 20, silver: 10, bronze: 5 }
  BADGE_SCORES = [ 5, 10, 20, 30, 50 ]
  NUMBER_FORMAT = /\A\d{1,7}(\.\d{1,3})?\z/
  # The biggest amount the server accepts in a question sent back (well above anything generated)
  MAX_AMOUNT = 1_000_000

  extend Topic::Playable
  extend self

  # Answers can have a decimal point at every level
  def keys(_level)
    [ "." ]
  end

  # Facts: a pair of units, one way round

  def facts(level = 1)
    level_details(level)[:types]
  end

  def fact_key(result)
    result["type"]
  end

  # Going to the smaller unit (multiplying) is easier than to the bigger (dividing), and bigger jumps are harder
  def difficulty(type)
    from, to = type.split(">")
    (factor(type) > 100 ? 1 : 0) + (smaller?(from, to) ? 0 : 1)
  end

  def trivial?(_type)
    false
  end

  # Questions

  # An amount in the bigger unit, tidy: whole, or with one or two decimal places (one for mm and cm, so the mm
  # are whole). Then asked either in that unit or the smaller one
  def question(type, level: 1, random:)
    places = factor(type) == 10 ? 1 : random.rand(0..2)
    bigger = places.zero? ? BigDecimal(random.rand(1..20)) : BigDecimal(random.rand(1..(places == 1 ? 99 : 999))) / BigDecimal(10)**places
    bigger += BigDecimal("0.5") if bigger.frac.zero? && places.positive?
    from, to = type.split(">")
    worked(type: type, a: smaller?(from, to) ? bigger * factor(type) : bigger)
  end

  # Worked out again from the amount, so the score never depends on the browser. A pair of units this level or
  # an easier one asks (a daily challenge mixes them), with a sensible amount
  def clean_result(result, level: 1)
    type = result["type"]
    amount = decimal(result["a"])
    raise Attempt::Invalid, "Bad question" unless (1..level).flat_map { |easier| facts(easier) }.include?(type)
    raise Attempt::Invalid, "Bad question" unless amount&.positive? && amount <= MAX_AMOUNT

    given = result["given"].to_s
    raise Attempt::Invalid, "Bad answer" unless given.match?(Attempt::TYPED_ANSWER)

    { "type" => type, "a" => written(amount), "given" => given, "correct" => given == written(converted(type, amount)) }
  end

  # A question written and answered as the game would, as for a lesson's one to try
  def worked(question)
    amount = decimal(question[:a])
    from, to = question[:type].split(">")
    { type: question[:type], a: written(amount), text: "#{written(amount)} #{from} = ? #{to}", answer: written(converted(question[:type], amount)) }
  end

  # "250 cm = 2.5 m"
  def label(result)
    amount = decimal(result["a"])
    from, to = result["type"].split(">")
    "#{written(amount)} #{from} = #{written(converted(result["type"], amount))} #{to}"
  end

  # Groups: each pair of units, one way round

  def groups(level = max_level)
    facts(level)
  end

  def groups_of(type)
    [ type ]
  end

  def group_label(type)
    type.sub(">", " → ")
  end

  def group_example(type)
    group_label(type)
  end

  def group_heading
    "Units"
  end

  def rankable_group?(_type)
    true
  end

  def feedback_groups(level)
    groups(level)
  end

  def practise_message(types)
    "Practise changing #{types.map { |type| group_label(type) }.to_sentence}"
  end

  def summary(best:, needs:)
    [ "You're best at changing #{best}", ("and #{needs} needs the most practice" if needs) ].compact.join(", ") + "."
  end

  # As typed: "2.5", "250". Exact decimals, so 0.35 km is 350 m
  def written(number)
    text = number.to_s("F")
    text.include?(".") ? text.sub(/0+\z/, "").delete_suffix(".") : text
  end

  private
    def level_details(number)
      level(number) || raise(Attempt::Invalid, "Unknown level")
    end

    def decimal(value)
      BigDecimal(value.to_s) if value.to_s.match?(NUMBER_FORMAT)
    end

    # How many of the smaller unit in one of the bigger, for a pair either way round
    def factor(type)
      from, to = type.split(">")
      UNITS.fetch("#{from}-#{to}") { UNITS.fetch("#{to}-#{from}") }
    end

    def smaller?(from, to)
      UNITS.key?("#{from}-#{to}")
    end

    # To a bigger unit divides, to a smaller one multiplies
    def converted(type, amount)
      from, to = type.split(">")
      smaller?(from, to) ? amount / factor(type) : amount * factor(type)
    end
end
