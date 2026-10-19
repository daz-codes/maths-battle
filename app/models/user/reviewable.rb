# Review: the questions a player recently got wrong in a topic, asked again exactly as they were. Taken from
# their last few games, and only the latest answer to each question counts, so getting one right takes it off
module User::Reviewable
  extend ActiveSupport::Concern

  REVIEW_GAMES = 10
  MAX_REVIEW_QUESTIONS = 20
  ANSWER_FIELDS = %w[ given correct ms ]

  # Latest mistakes first, each question once. Only ones the topic still asks at the player's level, as a
  # question from before a level changed would get the whole game refused
  def review_questions(topic)
    (@review_questions ||= {})[topic] ||= latest_answers(topic).reject { |result| result["correct"] }
      .map { |result| result.except(*ANSWER_FIELDS) }
      .filter_map { |question| askable(topic, question) }.first(MAX_REVIEW_QUESTIONS)
  end

  private
    # Each question's latest answer, newest first: the last game's last answer leads
    def latest_answers(topic)
      attempts.in_topic(topic).order(created_at: :desc, id: :desc).limit(REVIEW_GAMES)
        .flat_map { |game| game.results.reverse }.uniq { |result| result.except(*ANSWER_FIELDS) }
    end

    def askable(topic, question)
      worked = topic.worked(question.symbolize_keys)
      topic.clean_result(question.merge("given" => worked[:answer]), level: unlocked_level(topic))
      worked
    rescue Attempt::Invalid, KeyError, ArgumentError, NoMethodError, TypeError
      nil
    end
end
