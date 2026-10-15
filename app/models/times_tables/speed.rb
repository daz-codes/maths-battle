# Answer times. A right answer still needs practice if it was slow, but slow is judged against
# the player's own typical time, so a careful child doesn't find every fact flagged
module TimesTables::Speed
  # One distracted moment shouldn't wreck a fact's average
  MAX_COUNTED_MS = 10_000
  # Answers this quick are never slow, however fast the player usually is
  QUICK_ENOUGH_MS = 1_500
  # Slow means taking this many times the player's typical time, or more
  SLOW_FACTOR = 1.5

  def self.counted_ms(ms)
    ms.clamp(0, MAX_COUNTED_MS)
  end

  # The time a player usually takes, never below what's quick enough anyway
  def self.typical_ms(times)
    [ median(times) || QUICK_ENOUGH_MS, QUICK_ENOUGH_MS ].max
  end

  # 0 for a normal time, rising to 1 for twice the typical time or more
  def self.slowness(ms, typical_ms)
    ((ms - typical_ms).fdiv(typical_ms)).clamp(0.0, 1.0)
  end

  def self.slow?(ms, typical_ms)
    ms >= typical_ms * SLOW_FACTOR
  end

  def self.median(values)
    return if values.empty?

    sorted = values.sort
    middle = sorted.size / 2
    sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
  end
end
