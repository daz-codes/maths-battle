# Authorizes the questions issued for one game. Tickets work offline, expire after 30 days, and are
# bound to the browser's player. Their id is also the attempt's unique client id, preventing replay.
# A ticket also says whether it's for a daily challenge, so that's the server's word, not the browser's
class Attempt::GameTicket
  QUESTION_FIELDS = %w[ a b c d e f n type v flip ].freeze

  def self.issue(owner:, topic:, level:, id:, questions:, daily_challenge: false)
    verifier.generate({ "owner" => owner, "topic" => topic, "level" => level, "id" => id, "daily_challenge" => daily_challenge,
      "questions" => questions.map { |question| question.stringify_keys.slice(*QUESTION_FIELDS) } },
      expires_in: Attempt::MAX_OFFLINE_AGE, purpose: "game")
  end

  # Returns whether the game is a daily challenge (tickets from before there were any aren't)
  def self.verify!(ticket, owner:, topic:, level:, client_id:, results:)
    raise Attempt::Invalid, "Results must be a list" unless results.is_a?(Array)

    game = verifier.verified(ticket, purpose: "game") if ticket.is_a?(String) && ticket.bytesize <= 100_000
    unless game && game.values_at("owner", "topic", "level", "id") == [ owner, topic, Integer(level, exception: false), client_id ]
      raise Attempt::Invalid, "This game has expired or belongs to another player. Connect to load a new game."
    end
    questions = game.fetch("questions")
    unless results.size <= questions.size && results.each_with_index.all? { |result, index| result.is_a?(Hash) && result.stringify_keys.slice(*QUESTION_FIELDS) == questions[index] }
      raise Attempt::Invalid, "The answers don't match this game's questions"
    end
    game["daily_challenge"] == true
  end

  def self.verifier
    Rails.application.message_verifier("game-tickets")
  end
  private_class_method :verifier
end
