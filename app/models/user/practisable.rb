# Chooses a player's questions at random, weighted so that facts with a lower percentage correct,
# and facts answered right but slowly, come up more often and drop back as the player improves.
# A player who is struggling overall gets more easy questions and fewer hard ones, to build confidence
# back up; that eases off by itself as their recent accuracy rises
module User::Practisable
  QUESTION_COUNT = 150
  # Extra sets sent with each game page, so games played offline don't repeat the last set
  SPARE_QUESTION_SETS = 5
  TRIVIAL_WEIGHT = 0.1
  # A fact never answered right comes up this many times as often as one always answered right
  MAX_BOOST = 5
  # Extra weight for a fact answered right but slowly: up to this much for twice the player's typical time
  SLOW_BOOST = 2
  # A fact's average time only counts once it has been answered right this many times
  MIN_TIMED_ANSWERS = 2
  # Recent accuracy below this starts the shift towards easier questions…
  STRUGGLING_BELOW = 0.8
  # …and at this or lower it's at full strength
  FULLY_EASED_AT = 0.5
  RECENT_GAMES = 3
  MIN_RECENT_ANSWERS = 15
  # At full strength easy facts come up 3× as often, medium 1.5×, and hard ones 0.4×
  EASING = { 0 => 2.0, 1 => 0.5, 2 => -0.6 }

  def questions(count: QUESTION_COUNT, random: Random.new)
    previous = nil

    Array.new(count) do
      previous = pick_fact(excluding: previous, random: random)
      question_for(previous, random: random)
    end
  end

  # The set for this game, then spares for playing offline. Each has an id so the device knows which it has used
  def question_sets(count: 1 + SPARE_QUESTION_SETS)
    Array.new(count) { { id: SecureRandom.hex(6), questions: questions } }
  end

  def question_weights
    @question_weights ||= TimesTables.facts.index_with { |fact| question_weight(fact) }
  end

  # 0 for a player doing fine (or new), rising to 1 for one getting half or fewer right recently
  def easing
    @easing ||= recent_accuracy ? ((STRUGGLING_BELOW - recent_accuracy) / (STRUGGLING_BELOW - FULLY_EASED_AT)).clamp(0.0, 1.0) : 0.0
  end

  private
    def question_weight(fact)
      stat = times_tables_stats[TimesTables.fact_key(*fact)]
      base_weight(fact) * (1 + accuracy_boost(stat) + slow_boost(stat)) * difficulty_factor(fact)
    end

    def difficulty_factor(fact)
      1 + EASING.fetch(TimesTables.difficulty(fact)) * easing
    end

    def recent_accuracy
      answers = recent_answers
      answers.count { |answer| answer["correct"] }.fdiv(answers.size) if answers.size >= MIN_RECENT_ANSWERS
    end

    def recent_answers
      attempts.where(topic: TimesTables::TOPIC).order(created_at: :desc).limit(RECENT_GAMES).flat_map(&:results)
    end

    def base_weight(fact)
      TimesTables.trivial?(fact) ? TRIVIAL_WEIGHT : 1.0
    end

    # 0 for a fact always answered right (or not asked yet), up to MAX_BOOST - 1 for one never answered right
    def accuracy_boost(stat)
      (MAX_BOOST - 1) * (1 - (stat&.fraction_correct || 1.0))
    end

    def slow_boost(stat)
      timed?(stat) ? SLOW_BOOST * FactStat.slowness(stat.average_correct_ms, typical_answer_ms) : 0
    end

    def timed?(stat)
      stat.present? && stat.correct_count >= MIN_TIMED_ANSWERS
    end

    def typical_answer_ms
      @typical_answer_ms ||= FactStat.typical_ms(times_tables_stats.values.select { |stat| timed?(stat) }.map(&:average_correct_ms))
    end

    # Never the same fact twice in a row
    def pick_fact(excluding:, random:)
      candidates = question_weights.except(excluding)
      target = random.rand * candidates.values.sum

      candidates.each do |fact, weight|
        target -= weight
        return fact if target <= 0
      end
      candidates.keys.last
    end

    # Asked either way round: 7 × 8 or 8 × 7
    def question_for(fact, random:)
      a, b = random.rand < 0.5 ? fact : fact.reverse
      { a: a, b: b }
    end
end
