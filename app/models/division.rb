# The division topic: times tables the other way round. Each question is a table fact divided, 7 × 8 = 56
# asked as 56 ÷ 8, so it's tracked and grouped by table like times tables, with the same levels moving the
# numbers by powers of ten (Topic::Tabled): 21000 ÷ 70, 2.1 ÷ 0.7, 2100 ÷ 0.7
module Division
  include Topic::Tabled

  TOPIC = "division"
  SLUG = "division"
  NAME = "Division"
  EMOJI = "➗"
  LEVELS = [
    { number: 1, name: "Tables 2–5", example: "12 ÷ 3" },
    { number: 2, name: "Tables 2–12", example: "56 ÷ 8" },
    { number: 3, name: "Zeroes", example: "2400 ÷ 30" },
    { number: 4, name: "Decimals", example: "2.1 ÷ 0.7" },
    { number: 5, name: "Zeroes and decimals", example: "2100 ÷ 0.7" }
  ]
  # A level's practice earns a medal for its score; bronze unlocks the next level
  MEDALS = { gold: 20, silver: 10, bronze: 5 }
  # A little longer than times tables, as dividing is the harder way round
  STAR_TIMES = { lightning: 1_500, quick: 3_000 }
  BADGE_SCORES = [ 5, 10, 25, 50, 75, 100 ]

  extend Topic::Playable
  extend self

  # The table fact under a question: the number divided by and the answer. 2100 ÷ 0.7 is 7 × 3
  def fact_key(result)
    dividend, divisor = result.values_at("a", "b").map { |number| decimal(number) }
    fact_of(divisor, dividend / divisor)
  end

  # Questions

  # The fact's two numbers, moved for the level, multiplied, then divided by one of them: 2100 ÷ 0.7 = 3000
  def question(fact, level: 1, random:)
    divisor, quotient = scaled_factors(fact, level, random)
    worked(a: divisor * quotient, b: divisor)
  end

  # Checked and scored here rather than trusted: what it's divided by and the answer must both be numbers the
  # level could have asked, from one of its facts, so the answer comes out exactly
  def clean_result(result, level: 1)
    dividend, divisor = result.values_at("a", "b").map { |number| decimal(number) }
    raise Attempt::Invalid, "Bad question" unless dividend && divisor && allowed?(divisor, level)

    quotient = dividend / divisor
    raise Attempt::Invalid, "Bad question" unless quotient * divisor == dividend && allowed?(quotient, level)
    raise Attempt::Invalid, "Bad question" unless facts(level).include?(fact_of(divisor, quotient))

    given = result["given"].to_s
    raise Attempt::Invalid, "Bad answer" unless given.match?(Attempt::TYPED_ANSWER)

    { "a" => written(dividend), "b" => written(divisor), "given" => given, "correct" => given == written(quotient) }
  end

  # A question written and answered as the game would, as for a lesson's one to try
  def worked(question)
    dividend, divisor = question.values_at(:a, :b).map { |number| decimal(number) }
    { a: written(dividend), b: written(divisor), text: "#{shown(dividend)} ÷ #{shown(divisor)}", answer: written(dividend / divisor) }
  end

  # "56 ÷ 8 = 7"
  def label(result)
    dividend, divisor = result.values_at("a", "b").map { |number| decimal(number) }
    "#{shown(dividend)} ÷ #{shown(divisor)} = #{shown(dividend / divisor)}"
  end

  # Groups: each times table, as 56 ÷ 8 is the 7× and 8× tables

  def group_label(table)
    "#{table}×"
  end

  def practise_message(tables)
    "Practise dividing with your #{tables.map { |table| group_label(table) }.to_sentence} tables"
  end

  def summary(best:, needs:)
    [ "You divide best with the #{best} table", ("and dividing with the #{needs} table needs the most practice" if needs) ].compact.join(", ") + "."
  end
end
