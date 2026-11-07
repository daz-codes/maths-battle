# A battle: players racing each other in the same two minutes. A host makes one and shares its code (/live/K7Q2M), and
# whoever opens it joins the lobby (Joinable); or matchmaking puts together players looking for a game, and it starts
# at once (MatchRequest). Everyone's game begins together, each with their own questions, as hard as they can manage, with each
# other's scores ticking over as they play (Startable, LiveGameChannel). Power-ups drop for everyone as anyone
# answers another ten, and the first to tap one hits all the others with it (Droppable). A podium ranks them as they
# finish (Rankable), and then the host can play again with everyone (Rematchable)
class LiveGame < ApplicationRecord
  include Droppable, Joinable, Rankable, Rematchable, Startable

  belongs_to :host, class_name: "User", optional: true
  has_many :players, -> { order(:created_at, :id) }, dependent: :destroy
  has_many :users, through: :players

  def self.host!(host)
    create!(host: host).tap { |game| game.join(host) }
  end

  # Matchmaking's: everyone's in, and it starts at once
  def self.match!(users)
    create!(matched: true).tap do |game|
      users.each { |user| game.players.create!(user: user) }
      game.update!(starts_at: START_LEAD.from_now)
    end
  end

  def to_param
    code
  end

  def hosted_by?(user)
    user.present? && host_id == user.id
  end

  def player?(user)
    user.present? && players.exists?(user_id: user.id)
  end

  def player_for(user)
    players.find_by(user_id: user.id)
  end

  # Who's playing, for LiveGameChannel. The page says, signed, as a websocket opened in the lobby before joining
  # still has no one signed in on it
  def pass_for(user)
    self.class.passes.generate([ id, user.id ], expires_in: 1.hour)
  end

  def self.player_from_pass(pass)
    id, user_id = passes.verified(pass.to_s)
    LiveGame::Player.find_by(live_game_id: id, user_id: user_id) if id
  end

  def self.passes
    Rails.application.message_verifier("live-games")
  end
end
