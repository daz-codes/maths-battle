# Review: the questions a player recently got wrong or was slowest at in a topic, asked again exactly as they
# were. Taken from their last few games, slowest judged against their own typical time, as on results pages.
# Only the latest answer to each question counts, so getting one right and quick (in a review or any game)
# takes it off the list
module User::Reviewable
  extend ActiveSupport::Concern

  REVIEW_GAMES = 10
  MAX_REVIEW_QUESTIONS = 20
  ANSWER_FIELDS = %w[ given correct ms ]

  # Mistakes first, then the slowest right answers, each question once. Only ones the topic still asks at the
  # player's level, as a question from before a level changed would get the whole game refused
  def review_questions(topic)
    (@review_questions ||= {})[topic] ||= begin
      results = answers_to_review(topic)
      typical = FactStat.typical_ms(results.select { |result| result["correct"] }.map { |result| result["ms"] })
      latest = results.uniq { |result| result.except(*ANSWER_FIELDS) }
      mistakes = latest.reject { |result| result["correct"] }
      slow = latest.select { |result| result["correct"] && FactStat.slow?(result["ms"], typical) }.sort_by { |result| -result["ms"] }

      (mistakes + slow).map { |result| result.except(*ANSWER_FIELDS) }
        .filter_map { |question| askable(topic, question) }.first(MAX_REVIEW_QUESTIONS)
    end
  end

  private
    # Newest first: the last game's last answer leads
    def answers_to_review(topic)
      attempts.in_topic(topic).order(created_at: :desc, id: :desc).limit(REVIEW_GAMES).flat_map { |game| game.results.reverse }
    end

    def askable(topic, question)
      worked = topic.worked(question.symbolize_keys)
      topic.clean_result(question.merge("given" => worked[:answer]), level: unlocked_level(topic))
      worked
    rescue Attempt::Invalid, KeyError, ArgumentError, NoMethodError, TypeError
      nil
    end
end
