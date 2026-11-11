# Power-ups. A spinner appears at the top of the game after 3 answers, then 5 more, 8, 13, 21 and on, further apart
# each time (AT), flicking between them, and tapping it stops it and claims the one it lands on.
#
# Solo, they help the player, and the server deals them in the game's ticket, so the spinner lands on the one dealt
# and the server knows what was claimed and checks when (Attempt::GameTicket, Attempt::Scorable).
#
# In a battle, each player gets their own at the same answer counts, and an extra one when they've fallen far
# behind (LiveGame::Droppable). It hits everyone else. Most only slow them down; the Streak breaker and the Bomb change
# their scores, so their games take them where they hit
module PowerUp
  # The answer counts a spinner appears at: the gaps between them go 3, 5, 8, 13, 21, like the Fibonacci numbers
  AT = [ 3, 5 ].then do |gaps|
    gaps << gaps[-1] + gaps[-2] while gaps.sum + gaps[-1] + gaps[-2] <= Attempt::Recordable::MAX_ANSWERS
    gaps.each_with_object([]) { |gap, at| at << (at.last || 0) + gap }
  end

  # answers: how many right answers it lasts for
  SOLO = {
    # Small on purpose: each adds a little to the next few right answers, rather than multiplying the streak, so a
    # solo score is about answering well, not when a power-up came up. Stored as "double" and "triple", their names
    # when they did multiply
    "double" => { name: "Bonus +10", news: "+10 on each of your next 5 right answers!", answers: 5, points: 10 },
    "triple" => { name: "Bonus +20", news: "+20 on each of your next 5 right answers!", answers: 5, points: 20 },
    "boost" => { name: "Boost", news: "Boost: +30 on each of your next 5 right answers!", answers: 5, points: 30 },
    "shield" => { name: "Streak shield", news: "Streak shield: your next wrong answer won't break your streak" },
    "time" => { name: "Extra time", news: "+5 seconds!", seconds: 5 },
    "star" => { name: "Superstar", news: "Superstar! Your next 5 answers all count as right", answers: 5 },
    "coins" => { name: "Coins", news: "Coins! +100", points: 100 },
    "skip" => { name: "Skip", news: "Skip! Tap Skip to pass on a question without breaking your streak" }
  }
  # seconds: how long it lasts on everyone it hits. sent: what the player who claimed it did; hit: what it did to
  # each of the others, after their name. own: it helps the one who claims it, rather than hitting the others (the
  # others just hear they got it). The Bomb isn't dropped: a drop can turn out to be one when it's claimed by
  # someone far behind (LiveGame::Droppable)
  BATTLE = {
    "freeze" => { name: "Freeze", sent: "froze everyone else", hit: "froze you", seconds: 3 },
    "reset" => { name: "Streak breaker", sent: "broke everyone else's streaks", hit: "broke your streak" },
    "scramble" => { name: "Scramble", sent: "scrambled everyone else's keys", hit: "scrambled your keys", seconds: 5 },
    "ink" => { name: "Ink blot", sent: "inked everyone else's screens", hit: "inked your screen", seconds: 6 },
    "mini" => { name: "Mini text", sent: "shrank everyone else's questions", hit: "shrank your questions", seconds: 5 },
    "bomb" => { name: "Bomb", sent: "bombed everyone else's scores to zero", hit: "bombed your score to zero" },
    "mirror" => { name: "Mirror", sent: "flipped everyone else's questions", hit: "flipped your questions", seconds: 5 },
    "homing" => { name: "Homing shot", sent: "broke the leader's streak", hit: "broke your streak with a Homing shot" },
    "star" => { name: "Superstar", sent: "can't be hit, and your next 5 answers all count as right", hit: "got a Superstar", own: true, answers: 5 },
    "coins" => { name: "Coins", sent: "got 100 points", hit: "got Coins", own: true, points: 100 },
    # Stored as "horn", what it was called when it came in
    "horn" => { name: "Shield", sent: "will block the next attack on you", hit: "got a Shield", own: true },
    "curveball" => { name: "Curveball", sent: "threw everyone else 3 tough questions", hit: "threw you a Curveball: 3 tough questions", questions: 3 },
    "shot" => { name: "Shot", sent: "froze the player next to you", hit: "froze you with a Shot", seconds: 4 },
    "rocket" => { name: "Rocket", sent: "get 5 easy questions to catch up", hit: "got a Rocket", own: true, questions: 5 },
    "decoy" => { name: "Decoy", sent: "set a Decoy: everyone else's next power-up is a fake", hit: "set a Decoy", own: true, seconds: 3 },
    "skip" => { name: "Skip", sent: "can skip a question", hit: "got a Skip", own: true }
  }
  DROPPED = BATTLE.keys - %w[ bomb ]

  # One that hits the others, rather than helping the player who claimed it
  def self.attack?(kind)
    BATTLE.key?(kind) && !BATTLE.dig(kind, :own)
  end
  ALL = SOLO.merge(BATTLE)

  # A game can't have more than this many
  MOST = AT.size

  # When the nth spinner appears, from 1, and when the next takes its place, so the nth must be claimed before then
  def self.appears_at(drop)
    AT[drop - 1]
  end

  def self.replaced_at(drop)
    AT[drop] || Attempt::Recordable::MAX_ANSWERS + 1
  end

  def self.deal_solo(random: Random.new)
    Array.new(MOST) { SOLO.keys.sample(random: random) }
  end

  # Extra time is the only one that makes the game longer
  def self.extra_ms(kind)
    kind == "time" ? SOLO.dig("time", :seconds) * 1000 : 0
  end

  # For the game's page: names, what's said, and how long each lasts
  def self.rules
    { at: AT, all: ALL }
  end
end
