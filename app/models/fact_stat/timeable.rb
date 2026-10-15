# Answer times. A right answer still needs practice if it was slow, but slow is judged against
# the player's own typical time, so a careful child doesn't find every fact flagged
module FactStat::Timeable
  extend ActiveSupport::Concern

  # One distracted moment shouldn't wreck a fact's average
  MAX_COUNTED_MS = 10_000
  # Answers this quick are never slow, however fast the player usually is
  QUICK_ENOUGH_MS = 1_500
  # Slow means taking this many times the player's typical time, or more
  SLOW_FACTOR = 1.5

  class_methods do
    def total_counted_ms(answers)
      answers.sum { |answer| answer["ms"].clamp(0, MAX_COUNTED_MS) }
    end

    # The time a player usually takes, never below what's quick enough anyway
    def typical_ms(times)
      [ median(times) || QUICK_ENOUGH_MS, QUICK_ENOUGH_MS ].max
    end

    # 0 for a normal time, rising to 1 for twice the typical time or more
    def slowness(ms, typical_ms)
      (ms - typical_ms).fdiv(typical_ms).clamp(0.0, 1.0)
    end

    def slow?(ms, typical_ms)
      ms >= typical_ms * SLOW_FACTOR
    end

    private
      def median(values)
        return if values.empty?

        sorted = values.sort
        middle = sorted.size / 2
        sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
      end
  end

  # How long right answers take on average, or nil before any
  def average_correct_ms
    correct_ms / correct_count if correct_count.positive?
  end
end
