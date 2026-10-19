# Chooses a player's questions at random, weighted so that facts with a lower percentage correct,
# and facts answered right but slowly, come up more often and drop back as the player improves.
# A player who is struggling overall gets more easy questions and fewer hard ones, to build confidence
# back up; that eases off by itself as their recent accuracy rises.
# A level's practice asks only that level; the daily challenge mixes in every level up to it, so what was
# learnt at the easier ones isn't forgotten
module User::Practisable
  extend ActiveSupport::Concern

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

  # mix: :level_only for a level's practice, or :all_levels for a daily challenge, spread evenly over every
  # level up to this one
  def questions(topic: Topic.default, level: 1, count: QUESTION_COUNT, random: Random.new, mix: :level_only)
    previous, questions = nil, []

    while questions.size < count
      asked_at = question_level(level, random, mix)
      previous = pick_fact(topic, level, from: topic.facts(asked_at), excluding: previous, random: random)
      questions.concat(topic.questions_for(previous, level: asked_at, random: random))
    end
    questions.first(count)
  end

  # The set for this game, then spares for playing offline. Each has an id so the device knows which it has used
  def question_sets(topic: Topic.default, level: 1, count: 1 + SPARE_QUESTION_SETS, mix: :level_only)
    Array.new(count) { { id: SecureRandom.hex(16), questions: questions(topic: topic, level: level, mix: mix) } }
  end

  # A review's sets: the player's review questions, each once, in a new order each time
  def review_sets(topic:, count: 1 + SPARE_QUESTION_SETS, random: Random.new)
    Array.new(count) { { id: SecureRandom.hex(16), questions: review_questions(topic).shuffle(random: random) } }
  end

  def question_weights(topic = Topic.default, level = 1)
    (@question_weights ||= {})[[ topic, level ]] ||= topic.facts(level).index_with { |fact| question_weight(topic, level, fact) }
  end

  # 0 for a player doing fine at a level (or new to it), rising to 1 for one getting half or fewer right recently
  def easing(topic = Topic.default, level = 1)
    (@easing ||= {})[[ topic, level ]] ||= begin
      accuracy = recent_accuracy(topic, level)
      accuracy ? ((STRUGGLING_BELOW - accuracy) / (STRUGGLING_BELOW - FULLY_EASED_AT)).clamp(0.0, 1.0) : 0.0
    end
  end

  private
    def question_weight(topic, level, fact)
      stat = stats_for(topic, level)[fact]
      base_weight(topic, fact) * (1 + accuracy_boost(stat) + slow_boost(topic, level, stat)) * difficulty_factor(topic, level, fact)
    end

    def base_weight(topic, fact)
      topic.trivial?(fact) ? TRIVIAL_WEIGHT : 1.0
    end

    def difficulty_factor(topic, level, fact)
      1 + EASING.fetch(topic.difficulty(fact)) * easing(topic, level)
    end

    # 0 for a fact always answered right (or not asked yet), up to MAX_BOOST - 1 for one never answered right
    def accuracy_boost(stat)
      (MAX_BOOST - 1) * (1 - (stat&.fraction_correct || 1.0))
    end

    def slow_boost(topic, level, stat)
      timed?(stat) ? SLOW_BOOST * FactStat.slowness(stat.average_correct_ms, typical_answer_ms(topic, level)) : 0
    end

    def timed?(stat)
      stat.present? && stat.correct_count >= MIN_TIMED_ANSWERS
    end

    def typical_answer_ms(topic, level)
      (@typical_answer_ms ||= {})[[ topic, level ]] ||= FactStat.typical_ms(stats_for(topic, level).values.select { |stat| timed?(stat) }.map(&:average_correct_ms))
    end

    def recent_accuracy(topic, level)
      answers = recent_answers(topic, level)
      answers.count { |answer| answer["correct"] }.fdiv(answers.size) if answers.size >= MIN_RECENT_ANSWERS
    end

    def recent_answers(topic, level)
      attempts.at_level(topic, level).order(created_at: :desc).limit(RECENT_GAMES).flat_map(&:results)
    end

    def question_level(level, random, mix)
      mix == :all_levels ? random.rand(1..level) : level
    end

    # Weighted by how the player does at this level, from the facts the question's level can ask.
    # Never the same fact twice in a row, unless the level only has one
    def pick_fact(topic, level, from:, excluding:, random:)
      candidates = question_weights(topic, level).slice(*from)
      candidates = candidates.except(excluding) if candidates.size > 1
      target = random.rand * candidates.values.sum

      candidates.each do |fact, weight|
        target -= weight
        return fact if target <= 0
      end
      candidates.keys.last
    end
end
