# Works out what to say on the results page: the tables to practise and the facts missed today
class TimesTables::Feedback
  TABLES = 2..12
  MAX_WEAK_TABLES = 3
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
      "Every answer right. Brilliant!"
    else
      "Great work — keep your streak going!"
    end
  end

  # Today's mistakes, one per fact, as e.g. "7 × 8 = 56"
  def missed_facts
    @attempt.mistakes.uniq { |r| TimesTables.fact_key(r["a"], r["b"]) }.map do |r|
      "#{r["a"]} × #{r["b"]} = #{TimesTables.answer(r["a"], r["b"])}"
    end
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
