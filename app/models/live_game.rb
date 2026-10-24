# Players racing each other at the same moment. The host makes one from the Compete page and shares its link
# (/live/K7Q2MX); whoever opens it joins the lobby (Joinable), and when the host starts it everyone's game begins
# together, on the same questions, with each other's scores ticking over as they play (Startable, LiveGameChannel).
# Each player has one go, and a podium ranks them as they finish (Rankable). A Classic game is won by the most
# right answers; a Power game by the most gems, so speed and runs of right answers count too, with power-ups
# to slow the players ahead (Powerable)
class LiveGame < ApplicationRecord
  include Joinable, Powerable, Rankable, Startable

  belongs_to :host, class_name: "User"
  has_many :players, -> { order(:created_at, :id) }, dependent: :destroy
  has_many :users, through: :players

  MODES = %w[ classic power ]

  validates :topic, inclusion: { in: Topic.keys }
  validates :mode, inclusion: { in: MODES }
  validate :level_in_topic

  # The host's game, at their topic and level. Unweighted questions, like a group's, so no one's history shapes them
  def self.make(host:, topic:, level:)
    create!(host: host, topic: topic.key, level: level, questions: User.new.questions(topic: topic, level: level)).tap { |game| game.join(host) }
  end

  def to_param
    code
  end

  def topic_module
    Topic.find(topic)
  end

  def title
    "#{topic_module.title} · Level #{level}"
  end

  def power? = mode == "power"

  # The host picks, in the lobby, before it starts
  def choose_mode(mode)
    return false if started? || MODES.exclude?(mode)

    update!(mode: mode)
    broadcast_lobby
    true
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

  private
    def level_in_topic
      errors.add(:level, :inclusion) unless topic_module&.level(level)
    end
end
