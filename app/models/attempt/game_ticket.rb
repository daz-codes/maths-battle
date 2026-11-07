# Authorizes one game: the questions dealt for it, a pool for each tier (Ladder), and solo, the power-ups its spinners land on
# (PowerUp). Tickets are signed, bound to the browser's player, and expire after an hour. Their id is also the
# attempt's unique client id, so a game can't be saved twice. Checking a game walks the ladder again, so every
# answer must be to the question the browser should have asked, and every power-up one the ticket dealt, claimed
# no sooner than it appeared
class Attempt::GameTicket
  LIFETIME = 1.hour

  # top_tier: the hottest tier the temperature reached, from 1, kept for working out how hard games get
  Game = Data.define(:mode, :live_game_id, :results, :powers, :top_tier)

  def self.issue(owner:, id:, pools:, powers: [], live_game: nil)
    verifier.generate({ "owner" => owner, "id" => id, "mode" => live_game ? "battle" : "solo", "live_game" => live_game&.id,
      "pools" => pools, "powers" => powers }, expires_in: LIFETIME, purpose: "game")
  end

  # The checked answers, each marked right or wrong with its tier, and the power-ups claimed
  # shifts: where a battle's Curveballs and Rockets moved its questions, as the browser says, each checked against its
  # drop (LiveGame::Droppable#shifts_for). user: whose game it is, for a battle's
  def self.verify!(ticket, owner:, client_id:, answers:, claims:, shifts: [], user: nil)
    raise Attempt::Invalid, "Answers must be a list" unless answers.is_a?(Array) && claims.is_a?(Array) && shifts.is_a?(Array)
    raise Attempt::Invalid, "Too many answers" if answers.size > Attempt::Recordable::MAX_ANSWERS

    game = verifier.verified(ticket, purpose: "game") if ticket.is_a?(String) && ticket.bytesize <= 100_000
    unless game && game.values_at("owner", "id") == [ owner, client_id ]
      raise Attempt::Invalid, "This game has expired or belongs to another player. Start a new one."
    end

    pools = game.fetch("pools")
    live_game = LiveGame.find_by(id: game["live_game"]) if game["mode"] == "battle"
    shifted = live_game && user ? live_game.shifts_for(user, shifts, answers, pools.size) : {}
    results, highest = checked_answers(pools, answers, shifted)
    powers = game["mode"] == "solo" ? checked_claims(game.fetch("powers"), claims, results.size) : []
    check_skips(results, powers, live_game, user)
    Game.new(mode: game["mode"], live_game_id: game["live_game"], results:, powers:, top_tier: highest + 1)
  end

  # The answers, checked, and the highest tier they reached
  def self.checked_answers(pools, answers, shifts = {})
    results = []
    highest = Ladder.walk(pools, answers, shifts: shifts) do |answer, (op, a, b), tier|
      raise Attempt::Invalid, "Bad answer" unless answer.is_a?(Hash)

      answer = answer.stringify_keys
      raise Attempt::Invalid, "The answers don't match this game's questions" unless answer.values_at("op", "a", "b") == [ op, a, b ]

      given = answer["given"].to_s
      raise Attempt::Invalid, "Bad answer" unless given.match?(Attempt::Recordable::TYPED_ANSWER)

      ms = Integer(answer["ms"], exception: false)
      raise Attempt::Invalid, "Bad timing" unless ms&.between?(0, Attempt::Recordable::MAX_TOTAL_MS)

      if ActiveModel::Type::Boolean.new.cast(answer["skip"])
        results << { "op" => op, "a" => a, "b" => b, "given" => "", "ms" => ms, "correct" => false, "skip" => true, "tier" => tier }
        next :skip
      end

      correct = given == Ladder.answer(op, a, b)
      results << { "op" => op, "a" => a, "b" => b, "given" => given, "ms" => ms, "correct" => correct, "tier" => tier }
      [ correct, ms ]
    end
    [ results, highest ]
  end

  # Each spinner appears once its answers are in (PowerUp::AT), and the next one takes its place, so it's claimed at
  # most once, before then
  def self.checked_claims(dealt, claims, answered)
    claims.map do |claim|
      claim = claim.respond_to?(:to_h) ? claim.to_h.stringify_keys : {}
      drop, at = Integer(claim["drop"], exception: false), Integer(claim["at"], exception: false)
      raise Attempt::Invalid, "Bad power-up" unless drop&.between?(1, dealt.size) && at&.between?(PowerUp.appears_at(drop), [ PowerUp.replaced_at(drop) - 1, answered ].min)

      { "kind" => dealt[drop - 1], "drop" => drop, "at" => at }
    end.tap do |powers|
      raise Attempt::Invalid, "Bad power-up" unless powers.map { |power| power["drop"] }.uniq.size == powers.size
    end.sort_by { |power| power["at"] }
  end

  # Each question skipped needs a Skip claimed for it: solo, by then; in a battle, any this player tapped
  def self.check_skips(results, powers, live_game, user)
    skipped = results.each_index.select { |index| results[index]["skip"] }
    return if skipped.empty?

    if live_game
      raise Attempt::Invalid, "Bad skip" if user.nil? || skipped.size > live_game.drops.where(claimed_by: user, power_up: "skip").count
    else
      claimed = powers.select { |power| power["kind"] == "skip" }.map { |power| power["at"] }.sort
      skipped.each { |index| raise Attempt::Invalid, "Bad skip" unless (at = claimed.shift) && at <= index }
    end
  end

  def self.verifier
    Rails.application.message_verifier("game-tickets")
  end
  private_class_method :verifier, :checked_answers, :checked_claims, :check_skips
end
