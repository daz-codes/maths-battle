module GameTestHelper
  # A dealt ladder, the same every time for a seed
  def pools(seed: 1)
    Ladder.deal(random: Random.new(seed))
  end

  # Answers following the temperature as the browser would: rights is a list of true (right) and false (wrong),
  # each taking ms
  def walk_answers(pools, rights, ms: 1000)
    answers = []
    Ladder.walk(pools, rights) do |right, (op, a, b), _tier|
      answers << { "op" => op, "a" => a, "b" => b, "given" => right ? Ladder.answer(op, a, b) : "0", "ms" => ms }
      [ right, ms ]
    end
    answers
  end

  # A ticket's checked game, ready to record
  def checked_game(owner: "player", id: SecureRandom.hex(8), rights: [ true ] * 5, powers: PowerUp.deal_solo, claims: [], live_game: nil, ms: 1000)
    dealt = pools
    ticket = Attempt::GameTicket.issue(owner: owner, id: id, pools: dealt, powers: live_game ? [] : powers, live_game: live_game)
    Attempt::GameTicket.verify!(ticket, owner: owner, client_id: id, answers: walk_answers(dealt, rights, ms: ms), claims: claims)
  end

  def play(user, rights: [ true ] * 5, **options)
    Attempt.record!(user: user, game: checked_game(rights: rights, **options), client_id: SecureRandom.hex(8))
  end

  # The game's upload, as the browser sends it, with a ticket for the player the last response named
  def game_upload(rights: [ true ] * 5, powers: PowerUp.deal_solo, claims: [], live_game: nil, client_id: SecureRandom.hex(8), owner: nil)
    owner ||= begin
      get root_path
      response.headers.fetch("X-Player-Key")
    end
    dealt = pools
    ticket = Attempt::GameTicket.issue(owner: owner, id: client_id, pools: dealt, powers: powers, live_game: live_game)
    { attempt: { client_id: client_id, ticket: ticket, results: walk_answers(dealt, rights), claims: claims } }
  end
end
