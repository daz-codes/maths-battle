# Power-ups. Every EVERY answers a spinner appears at the top of the game, flicking between them, and tapping it
# stops it and claims the one it lands on.
#
# Solo, they help the player, and the server deals them in the game's ticket, so the spinner lands on the one dealt
# and the server knows what was claimed and checks when (Attempt::GameTicket, Attempt::Scorable).
#
# In a battle, one drops for everyone whenever any player answers another EVERY, and the first to tap it claims it
# (LiveGame::Droppable). It hits everyone else. Most only slow them down; the Streak breaker and the Bomb change
# their scores, so their games take them where they hit
module PowerUp
  EVERY = 10

  # answers: how many right answers it lasts for
  SOLO = {
    "double" => { name: "Double points", news: "Double points for your next 5 right answers!", answers: 5 },
    "triple" => { name: "Triple points", news: "Triple points for your next 5 right answers!", answers: 5 },
    "boost" => { name: "Boost", news: "Boost: +50 on each of your next 5 right answers!", answers: 5, points: 50 },
    "shield" => { name: "Streak shield", news: "Streak shield: your next wrong answer won't break your streak" },
    "time" => { name: "Extra time", news: "+5 seconds!", seconds: 5 },
    "star" => { name: "Superstar", news: "Superstar! Your next 5 answers all count as right", answers: 5 },
    "coins" => { name: "Coins", news: "Coins! +100", points: 100 }
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
    "horn" => { name: "Horn", sent: "will block the next attack on you", hit: "got a Horn", own: true }
  }
  DROPPED = BATTLE.keys - %w[ bomb ]

  # One that hits the others, rather than helping the player who claimed it
  def self.attack?(kind)
    BATTLE.key?(kind) && !BATTLE.dig(kind, :own)
  end
  ALL = SOLO.merge(BATTLE)

  # One every EVERY answers, so a game can't have more than this many
  MOST = Attempt::Recordable::MAX_ANSWERS / EVERY

  def self.deal_solo(random: Random.new)
    Array.new(MOST) { SOLO.keys.sample(random: random) }
  end

  # Extra time is the only one that makes the minute longer
  def self.extra_ms(kind)
    kind == "time" ? SOLO.dig("time", :seconds) * 1000 : 0
  end

  # For the game's page: names, what's said, and how long each lasts
  def self.rules
    { every: EVERY, all: ALL }
  end
end
