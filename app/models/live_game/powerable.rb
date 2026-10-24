# Power-ups in a Power game, like Mario Kart's item boxes: everyone gets a box at 15, 30 and 45 seconds, holding one
# at a time, and what's inside depends on their place, so the players behind get the strongest. Each attack hits the
# player just ahead (second place, for the leader), and Lightning everyone ahead; a Shield held blocks the next one.
# They only make another player slower, never change a score, so the podium still comes from the saved answers.
# The server deals every box and only accepts using what it dealt
module LiveGame::Powerable
  extend ActiveSupport::Concern

  # seconds: how long its effect lasts. A Shield isn't used: holding it is enough
  POWER_UPS = {
    "shield" => { name: "Shield" },
    "shrink" => { name: "Shrink", seconds: 5 },
    "flip" => { name: "Flip", seconds: 5 },
    "ink" => { name: "Ink splat", seconds: 5 },
    "freeze" => { name: "Freeze", seconds: 3 },
    "scramble" => { name: "Scramble", seconds: 5 },
    "lightning" => { name: "Lightning", seconds: 2 }
  }
  # Out of 100, by place when the box opens
  ODDS = {
    leading: { "shield" => 60, "shrink" => 25, "flip" => 15 },
    middle: { "shield" => 10, "shrink" => 20, "flip" => 20, "ink" => 20, "freeze" => 20, "scramble" => 10 },
    last: { "shrink" => 10, "flip" => 10, "ink" => 15, "freeze" => 25, "scramble" => 20, "lightning" => 20 }
  }
  BOX_EVERY = 15.seconds
  BOXES = 3
  # A box asked for a moment early, by a device's clock, still opens
  BOX_LEEWAY = 1.second

  # What's inside their next box, if it's time for one. It replaces what they're holding
  def open_box(player, random: Random.new)
    player.with_lock do
      box = player.boxes_opened + 1
      return unless power? && running? && box <= BOXES && Time.current >= starts_at + BOX_EVERY * box - BOX_LEEWAY

      player.update!(boxes_opened: box, power_up: draw(place_of_player(player), random))
      player.power_up
    end
  end

  # Using what they hold: who it hit, and whose Shield blocked it. Nil when there's nothing to use
  def use_power_up(player)
    transaction do
      power_up = player.lock!.power_up
      return unless running? && power_up && power_up != "shield"

      player.update!(power_up: nil)
      blocked, hit = targets_of(player, power_up).partition { |target| target.lock!.power_up == "shield" }
      blocked.each { |target| target.update!(power_up: nil) }
      { power_up: power_up, from: player.user_id, hit: hit.map(&:user_id), blocked: blocked.map(&:user_id) }
    end
  end

  # :leading, :middle or :last, by the gems each player last said they had. With two, the one behind is last
  def place_of_player(player)
    others = players.where.not(id: player.id).pluck(:live_gems)
    if others.all? { |gems| gems <= player.live_gems } then :leading
    elsif others.all? { |gems| gems >= player.live_gems } then :last
    else :middle
    end
  end

  private
    def draw(place, random)
      odds = ODDS.fetch(place)
      roll = random.rand(odds.values.sum)
      odds.find { |_, chance| (roll -= chance).negative? }.first
    end

    # The player just ahead, or second place for the leader. Lightning hits everyone ahead
    def targets_of(player, power_up)
      others = players.where.not(id: player.id).to_a
      ahead = others.select { |other| other.live_gems > player.live_gems }
      return ahead if power_up == "lightning"

      [ ahead.min_by(&:live_gems) || others.max_by(&:live_gems) ].compact
    end
end
