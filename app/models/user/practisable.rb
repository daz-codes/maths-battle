# Chooses a player's questions at random, weighted so that facts with a lower percentage correct,
# and facts answered right but slowly, come up more often and drop back as the player improves
module User::Practisable
  QUESTION_COUNT = 150
  TRIVIAL_FACTORS = [ 1, 10 ]
  TRIVIAL_WEIGHT = 0.1
  # A fact never answered right comes up this many times as often as one always answered right
  MAX_BOOST = 5
  # Extra weight for a fact answered right but slowly: up to this much for twice the player's typical time
  SLOW_BOOST = 2
  # A fact's average time only counts once it has been answered right this many times
  MIN_TIMED_ANSWERS = 2

  def questions(count: QUESTION_COUNT, random: Random.new)
    previous = nil

    Array.new(count) do
      previous = pick_fact(excluding: previous, random: random)
      question_for(previous, random: random)
    end
  end

  def question_weights
    @question_weights ||= TimesTables.facts.index_with { |fact| question_weight(fact) }
  end

  private
    def question_weight(fact)
      stat = times_tables_stats[TimesTables.fact_key(*fact)]
      base_weight(fact) * (1 + accuracy_boost(stat) + slow_boost(stat))
    end

    def base_weight(fact)
      fact.intersect?(TRIVIAL_FACTORS) ? TRIVIAL_WEIGHT : 1.0
    end

    # 0 for a fact always answered right (or not asked yet), up to MAX_BOOST - 1 for one never answered right
    def accuracy_boost(stat)
      (MAX_BOOST - 1) * (1 - (stat&.fraction_correct || 1.0))
    end

    def slow_boost(stat)
      timed?(stat) ? SLOW_BOOST * FactStat.slowness(stat.average_correct_ms, typical_answer_ms) : 0
    end

    def timed?(stat)
      stat.present? && stat.correct_count >= MIN_TIMED_ANSWERS
    end

    def typical_answer_ms
      @typical_answer_ms ||= FactStat.typical_ms(times_tables_stats.values.select { |stat| timed?(stat) }.map(&:average_correct_ms))
    end

    # Never the same fact twice in a row
    def pick_fact(excluding:, random:)
      candidates = question_weights.except(excluding)
      target = random.rand * candidates.values.sum

      candidates.each do |fact, weight|
        target -= weight
        return fact if target <= 0
      end
      candidates.keys.last
    end

    # Asked either way round: 7 × 8 or 8 × 7
    def question_for(fact, random:)
      a, b = random.rand < 0.5 ? fact : fact.reverse
      { a: a, b: b }
    end
end
