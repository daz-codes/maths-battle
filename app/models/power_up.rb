# Power-ups. Every EVERY answers a spinner appears at the top of the game, flicking between them, and tapping it
# stops it and claims the one it lands on.
#
# Solo, they help the player, and the server deals them in the game's ticket, so the spinner lands on the one dealt
# and the server knows what was claimed and checks when (Attempt::GameTicket, Attempt::Scorable).
#
# In a battle, one drops for everyone whenever any player answers another EVERY, and the first to tap it claims it
# (LiveGame::Droppable). It hits everyone else
module PowerUp
  EVERY = 10

  SOLO = {
    "double" => { name: "Double points", news: "Double points for your next 5 right answers!", answers: 5 },
    "shield" => { name: "Streak shield", news: "Streak shield: your next wrong answer won't break your streak" },
    "time" => { name: "Extra time", news: "+5 seconds!", seconds: 5 }
  }
  BATTLE = {
    "freeze" => { name: "Freeze", news: "froze", seconds: 3 },
    "reset" => { name: "Streak breaker", news: "broke the streak of" },
    "scramble" => { name: "Scramble", news: "scrambled the keys of", seconds: 5 }
  }
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
