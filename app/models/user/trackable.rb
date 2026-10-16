# A player's all-time record in a topic, for each of its groups (each times table, each type of equation):
# accuracy and average answer speed, and which group is their best and which needs the most practice
module User::Trackable
  # A group needs this many answers before it can be called best or worst
  MIN_ANSWERS_TO_RANK = 5

  Tally = Data.define(:group, :label, :right, :answered, :average_ms, :slow) do
    def percent
      (right * 100.0 / answered).round if answered.positive?
    end

    def slow?
      slow
    end
  end

  def tracked?(topic, level)
    overall_stats(topic, level).answered.positive?
  end

  def overall_stats(topic, level)
    tally(nil, "All", stats_for(topic, level).values)
  end

  def games_played(topic, level)
    attempts.in_topic(topic, level).count
  end

  # Over real games only: a test started and walked away from shouldn't drag it down
  def average_score(topic, level)
    attempts.counted.in_topic(topic, level).average(:score)&.round
  end

  def group_stats(topic, level)
    (@group_stats ||= {})[[ topic, level ]] ||= mark_slow_groups(topic.groups(level).map { |group| tally(group, topic.group_label(group), stats_for_group(topic, level, group)) })
  end

  # Best on accuracy, then speed
  def best_group(topic, level)
    ranked_groups(topic, level).first
  end

  def group_needing_practice(topic, level)
    ranked = ranked_groups(topic, level)
    ranked.last if ranked.many?
  end

  private
    def stats_for_group(topic, level, group)
      stats_for(topic, level).values.select { |stat| topic.groups_of(stat.fact).include?(group) }
    end

    def tally(group, label, stats)
      right = stats.sum(&:correct_count)
      average_ms = stats.sum(&:correct_ms) / right if right.positive?
      Tally.new(group:, label:, right:, answered: stats.sum(&:answered_count), average_ms:, slow: false)
    end

    def mark_slow_groups(tallies)
      typical = FactStat.typical_ms(tallies.filter_map(&:average_ms))
      tallies.map { |tally| tally.with(slow: tally.average_ms.present? && FactStat.slow?(tally.average_ms, typical)) }
    end

    def ranked_groups(topic, level)
      group_stats(topic, level).select { |tally| rankable?(topic, tally) }.sort_by { |tally| [ -tally.percent, tally.average_ms || Float::INFINITY ] }
    end

    def rankable?(topic, tally)
      tally.answered >= MIN_ANSWERS_TO_RANK && topic.rankable_group?(tally.group)
    end
end
