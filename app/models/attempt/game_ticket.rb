# Authorizes the questions issued for one game. Tickets work offline, expire after 30 days, and are
# bound to the browser's player. Their id is also the attempt's unique client id, preventing replay.
# A ticket also says the game's mode (practice, the daily challenge or a review), so that's the server's word,
# not the browser's
class Attempt::GameTicket
  QUESTION_FIELDS = %w[ a b c d e f n type v flip ].freeze

  # What a verified ticket says about its game: its mode, and for a group game its round, or a head to head's
  Game = Data.define(:mode, :round_id, :head_to_head_id)

  def self.issue(owner:, topic:, level:, id:, questions:, mode: "practice", round: nil, head_to_head: nil)
    verifier.generate({ "owner" => owner, "topic" => topic, "level" => level, "id" => id, "mode" => mode, "round" => round&.id, "head_to_head" => head_to_head&.id,
      "questions" => questions.map { |question| question.stringify_keys.slice(*QUESTION_FIELDS) } },
      expires_in: Attempt::MAX_OFFLINE_AGE, purpose: "game")
  end

  # Returns the game's mode and round. Tickets from before there were modes said only whether it was a daily challenge
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
    # Timed games can finish part way through their set; a review finishes after every issued question.
    if game["mode"] == "review" && results.size != questions.size
      raise Attempt::Invalid, "Answer every question to finish the review"
    end
    Game.new(mode: game["mode"] || (game["daily_challenge"] ? "challenge" : "practice"), round_id: game["round"], head_to_head_id: game["head_to_head"])
  end

  def self.verifier
    Rails.application.message_verifier("game-tickets")
  end
  private_class_method :verifier
end
