# Builds a weighted random list of questions. The lower a user's percentage correct on a fact,
# and the slower their right answers to it, the more often it comes up, so it drops back as they improve
class TimesTables::QuestionGenerator
  COUNT = 150
  TRIVIAL_FACTORS = [ 1, 10 ]
  TRIVIAL_WEIGHT = 0.1
  # A fact never answered right comes up this many times as often as one always answered right
  MAX_BOOST = 5
  # Extra weight for a fact answered right but slowly: up to this much for twice the player's typical time
  SLOW_BOOST = 2
  # A fact's average time only counts once it has been answered right this many times
  MIN_TIMED_ANSWERS = 2

  def initialize(user, count: COUNT, random: Random.new)
    @user, @count, @random = user, count, random
  end

  def questions
    previous = nil

    Array.new(@count) do
      fact = pick(excluding: previous)
      previous = fact
      a, b = @random.rand < 0.5 ? fact : fact.reverse
      { a: a, b: b }
    end
  end

  def weights
    @weights ||= facts.to_h { |fact| [ fact, weight_for(fact) ] }
  end

  private
    def facts
      TimesTables::FACTORS.to_a.repeated_combination(2).to_a
    end

    def weight_for(fact)
      base = fact.intersect?(TRIVIAL_FACTORS) ? TRIVIAL_WEIGHT : 1.0
      stat = stats[TimesTables.fact_key(*fact)]
      fraction_correct = stat&.fraction_correct || 1.0
      base * (1 + (MAX_BOOST - 1) * (1 - fraction_correct) + SLOW_BOOST * slowness(stat))
    end

    def slowness(stat)
      return 0 unless stat && stat.correct_count >= MIN_TIMED_ANSWERS

      TimesTables::Speed.slowness(stat.average_correct_ms, typical_ms)
    end

    def typical_ms
      @typical_ms ||= TimesTables::Speed.typical_ms(
        stats.values.select { |s| s.correct_count >= MIN_TIMED_ANSWERS }.map(&:average_correct_ms))
    end

    def stats
      @stats ||= @user.fact_stats.where(topic: TimesTables::TOPIC).index_by(&:fact)
    end

    def pick(excluding:)
      candidates = weights.except(excluding)
      target = @random.rand * candidates.values.sum

      candidates.each do |fact, weight|
        target -= weight
        return fact if target <= 0
      end
      candidates.keys.last
    end
end
