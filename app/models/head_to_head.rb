# Two players on the same questions. The challenger sends a game they've just played, or plays a rematch first,
# and the opponent then has a few days to beat their score. One go each: the first saved game is the one that
# counts. The opponent is someone the challenger already knows, by sharing a group or having played before
# (User::HeadToHeadable), or whoever opens the game's link first (Linkable). Wins, losses and draws add up across
# rematches
class HeadToHead < ApplicationRecord
  include Announceable, Decidable, Linkable

  TIME_TO_PLAY = 3.days

  belongs_to :challenger, class_name: "User"
  belongs_to :opponent, class_name: "User", optional: true
  belongs_to :challenger_attempt, class_name: "Attempt", optional: true
  belongs_to :opponent_attempt, class_name: "Attempt", optional: true
  belongs_to :winner, class_name: "User", optional: true

  validates :topic, inclusion: { in: Topic.keys }
  validate :level_in_topic
  validate :opponent_known, on: :create

  scope :involving, ->(user) { where(challenger: user).or(where(opponent: user)) }
  scope :between, ->(user, rival) { where(challenger: user, opponent: rival).or(where(challenger: rival, opponent: user)) }
  scope :sent, -> { where.not(challenger_attempt_id: nil) }
  scope :waiting, -> { sent.where(opponent_attempt_id: nil, expires_at: Time.current..) }
  scope :decided, -> { where.not(decided_at: nil) }

  class << self
    # A game the challenger has just played, sent as it is: the questions they answered, then more like them in case
    # the opponent gets further. No opponent sends it as a link
    def from_game(attempt, opponent: nil)
      played = attempt.results.map { |result| attempt.topic_module.worked(result.except(*User::ANSWER_FIELDS).symbolize_keys) }
      more = questions_for(attempt.topic_module, attempt.level, attempt.mixed?, count: User::QUESTION_COUNT - played.size)
      create!(challenger: attempt.user, opponent: opponent, topic: attempt.topic, level: attempt.level, mixed: attempt.mixed?,
        questions: played + more, challenger_attempt: attempt, expires_at: TIME_TO_PLAY.from_now)
    end

    # A new game for the challenger to play first, sent once they've played it
    def fresh(challenger:, opponent:, topic:, level:, mixed: false)
      create!(challenger: challenger, opponent: opponent, topic: topic.key, level: level, mixed: mixed, questions: questions_for(topic, level, mixed))
    end

    # Unweighted (a new player's questions), like a group's, so neither player's history shapes them
    def questions_for(topic, level, mixed, count: User::QUESTION_COUNT)
      User.new.questions(topic: topic, level: level, count: count, mix: mixed ? :all_levels : :level_only)
    end
  end

  def topic_module
    Topic.find(topic)
  end

  def title
    "#{topic_module.title} · #{mixed? ? "Mixed" : "Level #{level}"}"
  end

  def player?(user)
    user.present? && user.id.in?([ challenger_id, opponent_id ])
  end

  # Nil for the challenger of a link no one has opened yet
  def rival_of(user)
    user.id == challenger_id ? opponent : challenger
  end

  def attempt_of(user)
    user.id == challenger_id ? challenger_attempt : opponent_attempt
  end

  private
    def level_in_topic
      errors.add(:level, :inclusion) unless topic_module&.level(level)
    end

    def opponent_known
      errors.add(:opponent, "isn't someone you know") if opponent && !challenger&.rival?(opponent)
    end
end
