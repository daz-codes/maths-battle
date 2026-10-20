# The percentages topic: finding a percentage of a number, like 15% of 80. First the ones everything else is
# built from (50% and 10%, then 5% and 25%), then combinations of them (15% is 10% and 5%), then 1%, then any
# percentage. Each level practises its own; a daily challenge mixes them. The numbers are chosen so every
# answer is whole: it's about the method, not long decimals
module Percentages
  TOPIC = "percentages"
  SLUG = "percentages"
  NAME = "Percentages"
  EMOJI = "💯"

  # Each kind of percentage is a "fact": accuracy and speed are tracked per kind, and the weighting picks kinds.
  # Each kind's numbers are multiples of its step, so its answers come out whole
  TYPES = {
    "50"    => { difficulty: 0, form: "50%", example: "50% of 60", percents: [ 50 ], step: 10, up_to: 300 },
    "10"    => { difficulty: 0, form: "10%", example: "10% of 70", percents: [ 10 ], step: 10, up_to: 500 },
    "5"     => { difficulty: 1, form: "5%", example: "5% of 80", percents: [ 5 ], step: 20, up_to: 400 },
    "25"    => { difficulty: 1, form: "25%", example: "25% of 48", percents: [ 25 ], step: 4, up_to: 400 },
    "fives" => { difficulty: 2, form: "Made of 10% and 5%", example: "15% of 60", percents: (15..95).step(5).to_a - [ 25, 50 ], step: 20, up_to: 400 },
    "1"     => { difficulty: 1, form: "1%", example: "1% of 700", percents: [ 1 ], step: 100, up_to: 2000 },
    "any"   => { difficulty: 2, form: "Any percentage", example: "37% of 300", percents: (2..99).to_a - [ 5, 10, 25, 50 ], step: 100, up_to: 500 }
  }
  LEVELS = [
    { number: 1, name: "50% and 10%", example: "10% of 70", types: %w[ 50 10 ] },
    { number: 2, name: "5% and 25%", example: "25% of 48", types: %w[ 5 25 ] },
    { number: 3, name: "Combinations", example: "15% of 60", types: %w[ fives ] },
    { number: 4, name: "1%", example: "1% of 700", types: %w[ 1 ] },
    { number: 5, name: "Any percentage", example: "37% of 300", types: %w[ any ] }
  ]
  STAR_TIMES = { lightning: 3_000, quick: 6_000 }
  # A level's practice earns a medal for its score; bronze unlocks the next level
  MEDALS = { gold: 20, silver: 10, bronze: 5 }
  BADGE_SCORES = [ 5, 10, 20, 30, 50 ]

  extend Topic::Playable
  extend self

  # Every answer is a whole number, so just the digits
  def keys(_level)
    []
  end

  # Facts: kinds of percentage. A level's practice asks only its own; a daily challenge mixes in the ones before

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

  # A percentage of the kind, of a multiple of its step (never the step itself for 50%, as 50% of 10 is too easy)
  def question(type, level: 1, random:)
    details = TYPES.fetch(type)
    lowest = details[:step] * (type == "50" ? 2 : 1)
    worked(type: type, a: details[:percents].sample(random: random), b: (lowest..details[:up_to]).step(details[:step]).to_a.sample(random: random))
  end

  # Works the answer out again from the numbers, so the score never depends on the browser. A question from this
  # level or an easier one (a daily challenge mixes them), with numbers its kind could have used
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

  # "15% of 60 = 9"
  def label(result)
    question = question_from(result)
    "#{written(question)} = #{value(question)}"
  end

  # Groups: each kind of percentage

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
    "Practise percentages like #{types.map { |type| group_example(type) }.to_sentence}"
  end

  def summary(best:, needs:)
    [ "You're best at #{best}", ("and #{needs} needs the most practice" if needs) ].compact.join(", ") + "."
  end

  def value(question)
    question[:a] * question[:b] / 100
  end

  private
    def level_details(number)
      level(number) || raise(Attempt::Invalid, "Unknown level")
    end

    def question_from(result)
      type = result["type"]
      raise Attempt::Invalid, "Bad question" unless TYPES.key?(type)

      a, b = result.values_at("a", "b").map { |number| Integer(number, exception: false) }
      raise Attempt::Invalid, "Bad question" unless a && b

      { type: type, a: a, b: b }
    end

    # A percentage of the kind, of a number the kind could have used
    def possible?(question)
      details = TYPES.fetch(question[:type])
      details[:percents].include?(question[:a]) && question[:b].between?(details[:step], details[:up_to]) && (question[:b] % details[:step]).zero?
    end

    def written(question)
      "#{question[:a]}% of #{question[:b]}"
    end
end
