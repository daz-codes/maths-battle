# Makes a daily challenge's questions: new ones every game, so it can be played again and again, but every set
# as hard as any other, so scores from different games can still be ranked against each other.
#
# The level's facts are ranked by how hard players find them, from everyone's answers (FactStat): how often they're
# got wrong, and how slowly they're got right. The ranking is split into easy, medium and hard thirds (tiers), and
# each set takes one question from each tier in turn, in a new order each time round. Whatever a player reaches in
# their minute, their questions so far are a third easy, a third medium and a third hard.
#
# Facts with few answers lean on the topic's own idea of how hard they are (Topic#difficulty), until there's enough
# data to go on. The tiers are worked out once a day, so all of a day's games are balanced the same way
class DailyTest::Balancer
  TIERS = 3
  # How a fact is expected to go before anyone's answered it, by the topic's difficulty for it (0 easy to 2 hard)
  EXPECTED_ACCURACY = { 0 => 0.95, 1 => 0.88, 2 => 0.78 }
  # A fact's own answers outweigh that expectation once there are more than this many
  PRIOR_ANSWERS = 20
  # Being slow to get a fact right counts for this much, against getting it wrong as 1
  SLOWNESS_WEIGHT = 0.15
  # A fact's speed only counts once it's been got right this many times
  MIN_TIMED_ANSWERS = 5
  # Facts almost everyone finds trivial (×1, ×10) are still asked, but rarely
  TRIVIAL_WEIGHT = 0.1

  attr_reader :topic, :level

  def initialize(topic, level, day: Date.current)
    @topic, @level, @day = topic, level, day
  end

  def questions(count:, random: Random.new)
    questions, previous = [], nil
    while questions.size < count
      tiers.each_index.to_a.shuffle(random: random).each do |tier|
        previous = pick(tiers[tier], excluding: previous, random: random)
        questions.concat(topic.questions_for(previous, level: level, random: random))
      end
    end
    questions.first(count)
  end

  # The level's facts in TIERS groups, easiest first
  def tiers
    @tiers ||= Rails.cache.fetch([ "daily-test-tiers", topic.key, level, @day.iso8601 ], expires_in: 1.day) do
      ranked = topic.facts(level).sort_by { |fact| [ hardness(fact), topic.difficulty(fact), fact ] }
      ranked.each_slice((ranked.size / TIERS.to_f).ceil).to_a
    end
  end

  # How hard players find a fact: its share of wrong answers, plus a little for slow right ones
  def hardness(fact)
    (1 - accuracy(fact)) + SLOWNESS_WEIGHT * slowness(fact)
  end

  private
    def accuracy(fact)
      right, wrong, _ = totals.fetch(fact, [ 0, 0, 0 ])
      (right + EXPECTED_ACCURACY.fetch(topic.difficulty(fact), EXPECTED_ACCURACY[1]) * PRIOR_ANSWERS) / (right + wrong + PRIOR_ANSWERS).to_f
    end

    # −1 to 1: how much slower (or quicker) a fact's right answers are than a typical fact's
    def slowness(fact)
      ms = average_ms(fact)
      ms && typical_ms ? ((ms - typical_ms) / typical_ms).clamp(-1.0, 1.0) : 0.0
    end

    def average_ms(fact)
      right, _, ms = totals[fact]
      ms.fdiv(right) if right.to_i >= MIN_TIMED_ANSWERS
    end

    def typical_ms
      @typical_ms ||= begin
        times = topic.facts(level).filter_map { |fact| average_ms(fact) }.sort
        times[times.size / 2] if times.any?
      end
    end

    # Everyone's answers to each of the level's facts: right, wrong, and the time the right ones took
    def totals
      @totals ||= FactStat.where(topic: topic.key, level: level).group(:fact)
        .pluck(:fact, Arel.sql("SUM(correct_count)"), Arel.sql("SUM(wrong_count)"), Arel.sql("SUM(correct_ms)"))
        .to_h { |fact, right, wrong, ms| [ fact, [ right.to_i, wrong.to_i, ms.to_i ] ] }
    end

    # A fact from the tier, never the one just asked if there's another, with trivial facts coming up rarely
    def pick(facts, excluding:, random:)
      candidates = facts.size > 1 ? facts - [ excluding ] : facts
      weights = candidates.map { |fact| topic.trivial?(fact) ? TRIVIAL_WEIGHT : 1.0 }
      target = random.rand * weights.sum
      candidates.zip(weights).each do |fact, weight|
        target -= weight
        return fact if target <= 0
      end
      candidates.last
    end
end
