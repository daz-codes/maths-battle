# What to say on the results page: the tables to practise, and the facts missed or slow today
module Attempt::Reviewable
  TABLES = 2..12
  MAX_WEAK_TABLES = 3
  MAX_SLOW_FACTS = 5
  GOOD_ENOUGH = 0.9
  HISTORY = 14.days

  def feedback_message
    if answered.zero?
      "Have another go — type your answers as fast as you can!"
    elsif weak_tables.any?
      "Practise your #{weak_tables.map { |table| "#{table}×" }.to_sentence} tables"
    elsif perfect?
      "Every answer right. Brilliant#{with_name}!"
    else
      "Great work#{with_name} — keep your streak going!"
    end
  end

  # Today's mistakes, one per fact, as e.g. "7 × 8 = 56"
  def missed_facts
    mistakes.uniq { |result| fact_key(result) }.map { |result| fact_label(result) }
  end

  # Today's right answers that took much longer than this player usually takes, slowest first
  def slow_facts
    slow_answers
      .sort_by { |result| -result["ms"] }
      .uniq { |result| fact_key(result) }
      .reject { |result| missed_fact_keys.include?(fact_key(result)) }
      .first(MAX_SLOW_FACTS)
      .map { |result| fact_label(result) }
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
    def with_name
      ", #{user.display_name}" if user.display_name
    end

    def fact_label(result)
      "#{result["a"]} × #{result["b"]} = #{topic_module.answer(result["a"], result["b"])}"
    end

    def right_answers
      results.select { |result| result["correct"] }
    end

    def slow_answers
      typical = FactStat.typical_ms(right_answers.map { |result| result["ms"] })
      right_answers.select { |result| FactStat.slow?(result["ms"], typical) }
    end

    def missed_fact_keys
      mistakes.map { |result| fact_key(result) }
    end

    # [right, total] for each table. A fact like 7×8 counts toward both tables, a square like 7×7 once
    def accuracy_by_table
      TABLES.index_with { [ 0, 0 ] }.tap do |tally|
        recent_results.each { |result| tally_result(tally, result) }
      end
    end

    def tally_result(tally, result)
      [ result["a"], result["b"] ].uniq.each do |table|
        next unless tally.key?(table)

        tally[table][0] += 1 if result["correct"]
        tally[table][1] += 1
      end
    end

    def recent_results
      user.attempts.where(topic: topic, created_at: (created_at - HISTORY)..created_at).flat_map(&:results)
    end
end
