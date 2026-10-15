# Builds a weighted random list of questions, so facts a user gets wrong come up more often
class TimesTables::QuestionGenerator
  COUNT = 150
  TRIVIAL_FACTORS = [ 1, 10 ]
  TRIVIAL_WEIGHT = 0.1
  RECENT_WRONG_BONUS = 2
  RECENT = 7.days

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
      return base unless stat

      total = stat.correct_count + stat.wrong_count
      weight = base * (1 + 4.0 * stat.wrong_count / (total + 1))
      weight += RECENT_WRONG_BONUS if stat.last_wrong_at&.after?(RECENT.ago)
      weight
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
