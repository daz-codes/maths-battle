# A player's all-time record for each times table: accuracy and average answer speed,
# and which table is their best and which needs the most practice
module User::Trackable
  # A table needs this many answers before it can be called best or worst
  MIN_ANSWERS_TO_RANK = 5

  Tally = Data.define(:table, :right, :answered, :average_ms, :slow) do
    def label
      table ? "#{table}×" : "All tables"
    end

    def percent
      (right * 100.0 / answered).round if answered.positive?
    end

    def slow?
      slow
    end
  end

  def tracked?
    overall_stats.answered.positive?
  end

  def overall_stats
    @overall_stats ||= tally(nil, times_tables_stats.values)
  end

  def games_played
    attempts.where(topic: TimesTables::TOPIC).count
  end

  # Over real games only: a test started and walked away from shouldn't drag it down
  def average_score
    counted_games.average(:score)&.round
  end

  # One tally per table, 1× to 12×. A fact like 7×8 counts toward both the 7× and 8× tables
  def table_stats
    @table_stats ||= mark_slow_tables(TimesTables::FACTORS.map { |table| tally(table, stats_for_table(table)) })
  end

  # Best on accuracy, then speed
  def best_table
    ranked_tables.first
  end

  def table_needing_practice
    ranked_tables.last if ranked_tables.many?
  end

  private
    def counted_games
      attempts.where(topic: TimesTables::TOPIC, answered: Attempt::MIN_ANSWERS_FOR_STREAK..)
    end

    def stats_for_table(table)
      times_tables_stats.values.select { |stat| factors_of(stat).include?(table) }
    end

    def factors_of(stat)
      stat.fact.split("x").map(&:to_i)
    end

    def tally(table, stats)
      right = stats.sum(&:correct_count)
      average_ms = stats.sum(&:correct_ms) / right if right.positive?
      Tally.new(table:, right:, answered: stats.sum(&:answered_count), average_ms:, slow: false)
    end

    def ranked_tables
      @ranked_tables ||= table_stats.select { |tally| rankable?(tally) }.sort_by { |tally| [ -tally.percent, tally.average_ms || Float::INFINITY ] }
    end

    def rankable?(tally)
      tally.answered >= MIN_ANSWERS_TO_RANK && TimesTables::TRIVIAL_FACTORS.exclude?(tally.table)
    end

    def mark_slow_tables(tallies)
      typical = FactStat.typical_ms(tallies.filter_map(&:average_ms))
      tallies.map { |tally| tally.with(slow: tally.average_ms.present? && FactStat.slow?(tally.average_ms, typical)) }
    end
end
