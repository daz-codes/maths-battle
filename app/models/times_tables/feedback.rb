# Works out what to say on the results page: the tables to practise, and the facts missed or slow today
class TimesTables::Feedback
  TABLES = 2..12
  MAX_WEAK_TABLES = 3
  MAX_SLOW_FACTS = 5
  GOOD_ENOUGH = 0.9
  HISTORY = 14.days

  def initialize(attempt)
    @attempt = attempt
  end

  def message
    if @attempt.answered.zero?
      "Have another go — type your answers as fast as you can!"
    elsif weak_tables.any?
      "Practise your #{weak_tables.map { |t| "#{t}×" }.to_sentence} tables"
    elsif @attempt.perfect?
      "Every answer right. Brilliant#{name}!"
    else
      "Great work#{name} — keep your streak going!"
    end
  end

  # Today's mistakes, one per fact, as e.g. "7 × 8 = 56"
  def missed_facts
    @attempt.mistakes.uniq { |r| TimesTables.fact_key(r["a"], r["b"]) }.map do |r|
      "#{r["a"]} × #{r["b"]} = #{TimesTables.answer(r["a"], r["b"])}"
    end
  end

  # Today's right answers that took much longer than this player usually takes, slowest first
  def slow_facts
    right = @attempt.results.select { |r| r["correct"] }
    typical = TimesTables::Speed.typical_ms(right.map { |r| r["ms"] })
    missed = @attempt.mistakes.map { |r| TimesTables.fact_key(r["a"], r["b"]) }

    right.select { |r| TimesTables::Speed.slow?(r["ms"], typical) }
      .sort_by { |r| -r["ms"] }
      .uniq { |r| TimesTables.fact_key(r["a"], r["b"]) }
      .reject { |r| missed.include?(TimesTables.fact_key(r["a"], r["b"])) }
      .first(MAX_SLOW_FACTS)
      .map { |r| "#{r["a"]} × #{r["b"]} = #{TimesTables.answer(r["a"], r["b"])}" }
  end

  # The tables with the worst accuracy over this attempt and the two weeks before it
  def weak_tables
    @weak_tables ||= accuracy_by_table
      .select { |_, (right, total)| total.positive? && right.fdiv(total) < GOOD_ENOUGH }
      .sort_by { |table, (right, total)| [ right.fdiv(total), table ] }
      .first(MAX_WEAK_TABLES)
      .map(&:first)
      .sort
  end

  private
    def name
      ", #{@attempt.user.display_name}" if @attempt.user.display_name
    end

    def accuracy_by_table
      TABLES.index_with { [ 0, 0 ] }.tap do |tally|
        recent_results.each do |r|
          [ r["a"], r["b"] ].uniq.each do |table|
            next unless tally.key?(table)
            tally[table][0] += 1 if r["correct"]
            tally[table][1] += 1
          end
        end
      end
    end

    def recent_results
      @attempt.user.attempts
        .where(topic: @attempt.topic, created_at: (@attempt.created_at - HISTORY)..@attempt.created_at)
        .flat_map(&:results)
    end
end
