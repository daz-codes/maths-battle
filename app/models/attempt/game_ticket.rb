# Authorizes one game: the ladder's questions dealt for it (Ladder), and solo, the power-ups its spinners land on
# (PowerUp). Tickets are signed, bound to the browser's player, and expire after an hour. Their id is also the
# attempt's unique client id, so a game can't be saved twice. Checking a game walks the ladder again, so every
# answer must be to the question the browser should have asked, and every power-up one the ticket dealt, claimed
# no sooner than it appeared
class Attempt::GameTicket
  LIFETIME = 1.hour

  # top_tier: the highest the ladder reached, from 1
  Game = Data.define(:mode, :live_game_id, :results, :powers, :top_tier)

  def self.issue(owner:, id:, pools:, powers: [], live_game: nil)
    verifier.generate({ "owner" => owner, "id" => id, "mode" => live_game ? "battle" : "solo", "live_game" => live_game&.id,
      "pools" => pools, "powers" => powers }, expires_in: LIFETIME, purpose: "game")
  end

  # The checked answers, each marked right or wrong with its tier, and the power-ups claimed
  def self.verify!(ticket, owner:, client_id:, answers:, claims:)
    raise Attempt::Invalid, "Answers must be a list" unless answers.is_a?(Array) && claims.is_a?(Array)
    raise Attempt::Invalid, "Too many answers" if answers.size > Attempt::Recordable::MAX_ANSWERS

    game = verifier.verified(ticket, purpose: "game") if ticket.is_a?(String) && ticket.bytesize <= 100_000
    unless game && game.values_at("owner", "id") == [ owner, client_id ]
      raise Attempt::Invalid, "This game has expired or belongs to another player. Start a new one."
    end

    results, highest = checked_answers(game.fetch("pools"), answers)
    powers = game["mode"] == "solo" ? checked_claims(game.fetch("powers"), claims, results.size) : []
    Game.new(mode: game["mode"], live_game_id: game["live_game"], results:, powers:, top_tier: highest + 1)
  end

  # The answers, checked, and the highest tier they reached
  def self.checked_answers(pools, answers)
    results = []
    highest = Ladder.walk(pools, answers) do |answer, (op, a, b), tier|
      raise Attempt::Invalid, "Bad answer" unless answer.is_a?(Hash)

      answer = answer.stringify_keys
      raise Attempt::Invalid, "The answers don't match this game's questions" unless answer.values_at("op", "a", "b") == [ op, a, b ]

      given = answer["given"].to_s
      raise Attempt::Invalid, "Bad answer" unless given.match?(Attempt::Recordable::TYPED_ANSWER)

      ms = Integer(answer["ms"], exception: false)
      raise Attempt::Invalid, "Bad timing" unless ms&.between?(0, Attempt::Recordable::MAX_TOTAL_MS)

      correct = given == Ladder.answer(op, a, b)
      results << { "op" => op, "a" => a, "b" => b, "given" => given, "ms" => ms, "correct" => correct, "tier" => tier }
      correct
    end
    [ results, highest ]
  end

  # Each spinner appears once its EVERY answers are in, and the next one takes its place, so it's claimed at most
  # once, before then
  def self.checked_claims(dealt, claims, answered)
    claims.map do |claim|
      claim = claim.respond_to?(:to_h) ? claim.to_h.stringify_keys : {}
      drop, at = Integer(claim["drop"], exception: false), Integer(claim["at"], exception: false)
      raise Attempt::Invalid, "Bad power-up" unless drop&.between?(1, dealt.size) && at&.between?(drop * PowerUp::EVERY, [ (drop + 1) * PowerUp::EVERY - 1, answered ].min)

      { "kind" => dealt[drop - 1], "drop" => drop, "at" => at }
    end.tap do |powers|
      raise Attempt::Invalid, "Bad power-up" unless powers.map { |power| power["drop"] }.uniq.size == powers.size
    end.sort_by { |power| power["at"] }
  end

  def self.verifier
    Rails.application.message_verifier("game-tickets")
  end
  private_class_method :verifier, :checked_answers, :checked_claims
end
