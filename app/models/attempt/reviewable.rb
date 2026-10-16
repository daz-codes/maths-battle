# What to say on the results page: the groups to practise (times tables, types of equation),
# and the questions missed or slow today
module Attempt::Reviewable
  MAX_WEAK_GROUPS = 3
  MAX_SLOW_FACTS = 5
  GOOD_ENOUGH = 0.9
  HISTORY = 14.days

  def feedback_message
    if answered.zero?
      "Have another go — type your answers as fast as you can!"
    elsif weak_groups.any?
      topic_module.practise_message(weak_groups)
    elsif perfect?
      "Every answer right. Brilliant#{with_name}!"
    else
      "Great work#{with_name} — keep your streak going!"
    end
  end

  # Today's mistakes, one per fact, as e.g. "7 × 8 = 56" or "2y + 7 = 11, so y = 2"
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

  # The groups with the worst accuracy over this attempt and the two weeks before it
  def weak_groups
    @weak_groups ||= accuracy_by_group
      .select { |_, (right, total)| total.positive? && right.fdiv(total) < GOOD_ENOUGH }
      .sort_by { |group, (right, total)| [ right.fdiv(total), topic_module.groups(level).index(group) ] }
      .first(MAX_WEAK_GROUPS)
      .map(&:first)
      .sort_by { |group| topic_module.groups(level).index(group) }
  end

  private
    def with_name
      ", #{user.display_name}" if user.display_name
    end

    def fact_label(result)
      topic_module.label(result)
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

    # [right, total] for each group. In times tables 7×8 counts toward both tables, 7×7 once
    def accuracy_by_group
      topic_module.feedback_groups(level).index_with { [ 0, 0 ] }.tap do |tally|
        recent_results.each { |result| tally_result(tally, result) }
      end
    end

    def tally_result(tally, result)
      topic_module.groups_of(fact_key(result)).each do |group|
        next unless tally.key?(group)

        tally[group][0] += 1 if result["correct"]
        tally[group][1] += 1
      end
    end

    def recent_results
      user.attempts.where(topic: topic, level: level, created_at: (created_at - HISTORY)..created_at).flat_map(&:results)
    end
end
