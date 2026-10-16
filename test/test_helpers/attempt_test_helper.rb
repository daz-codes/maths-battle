module AttemptTestHelper
  # Controller requests include a ticket from the server. Model tests still exercise recording directly.
  def game_upload(results:, topic: Topic.default.key, level: 1, client_id: SecureRandom.hex(12), **options)
    get root_path
    owner = response.headers.fetch("X-Player-Key")
    questions = results.is_a?(Array) ? results : []
    ticket = Attempt::GameTicket.issue(owner: owner, topic: topic, level: level, id: client_id, questions: questions)
    { attempt: { topic: topic, level: level, client_id: client_id, ticket: ticket, player_key: owner, results: results, **options } }
  end

  # Answers in the shape the browser sends. Pass [a, b, given] triples
  def answers(*triples, ms: 1000)
    triples.map { |a, b, given| { a: a, b: b, given: given, ms: ms } }
  end

  def right_answers(count)
    Array.new(count) { |i| [ 2 + i % 11, 3, (2 + i % 11) * 3 ] }
  end

  # A times tables game at level 2, which asks every table from 2 to 12 (level 1 is just the 2–5 tables)
  def record_tables_game(user, results, **options)
    unlock(user, TimesTables, 2) if user.unlocked_level(TimesTables) < 2
    Attempt.record!(user: user, level: 2, results: results, **options)
  end

  # Plays enough good games at each level below to unlock this one. The questions are ones every level asks
  def unlock(user, topic, level)
    easy = topic == Equations ? { type: "x+a=b", a: 2, b: 5, v: "x", flip: false, given: "3", ms: 1000 } : { a: 2, b: 3, given: 6, ms: 1000 }

    (1...level).each do |below|
      User::Levelable::GOOD_GAMES_TO_LEVEL_UP.times do
        Attempt.record!(user: user, topic: topic.key, level: below, results: [ easy ] * Attempt::GOOD_GAME_ANSWERS)
      end
    end
  end
end
