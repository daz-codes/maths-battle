# A player's all-time record for each times table: percentage right and average answer speed
class TimesTables::Stats
  Row = Data.define(:label, :right, :answered, :average_ms, :slow) do
    def percent
      (right * 100.0 / answered).round if answered.positive?
    end

    def slow?
      slow
    end
  end

  def initialize(user)
    @user = user
  end

  def any?
    overall.answered.positive?
  end

  def overall
    @overall ||= row_for("All tables", stats)
  end

  def games
    @user.attempts.where(topic: TimesTables::TOPIC).count
  end

  # One row per table, 1× to 12×. A fact like 7×8 counts toward both the 7× and 8× tables
  def tables
    @tables ||= begin
      rows = TimesTables::FACTORS.map do |table|
        row_for("#{table}×", stats.select { |s| factors(s).include?(table) })
      end
      typical = TimesTables::Speed.typical_ms(rows.filter_map(&:average_ms))
      rows.map { |row| row.with(slow: row.average_ms.present? && TimesTables::Speed.slow?(row.average_ms, typical)) }
    end
  end

  private
    def stats
      @stats ||= @user.fact_stats.where(topic: TimesTables::TOPIC).to_a
    end

    def factors(stat)
      stat.fact.split("x").map(&:to_i)
    end

    def row_for(label, stats)
      right = stats.sum(&:correct_count)
      answered = stats.sum(&:answered_count)
      average_ms = stats.sum(&:correct_ms) / right if right.positive?
      Row.new(label:, right:, answered:, average_ms:, slow: false)
    end
end
