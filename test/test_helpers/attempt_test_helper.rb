module AttemptTestHelper
  # Answers in the shape the browser sends. Pass [a, b, given] triples
  def answers(*triples, ms: 1000)
    triples.map { |a, b, given| { a: a, b: b, given: given, ms: ms } }
  end

  def right_answers(count)
    Array.new(count) { |i| [ 2 + i % 11, 3, (2 + i % 11) * 3 ] }
  end

  # Plays enough good games at each level below to unlock this one. The questions are ones every level asks
  def unlock(user, topic, level)
    easy = topic == Equations ? { type: "x+a=b", a: 2, b: 5, v: "x", flip: false, given: "3", ms: 1000 } : { a: 2, b: 3, given: 6, ms: 1000 }

    (1...level).each do |below|
      User::Levelable::GOOD_GAMES_TO_LEVEL_UP.times do
        Attempt.record!(user: user, topic: topic::TOPIC, level: below, results: [ easy ] * User::Levelable::GOOD_GAME_ANSWERS)
      end
    end
  end
end
