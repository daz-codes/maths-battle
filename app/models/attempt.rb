class Attempt < ApplicationRecord
  include Badgeable, Gemmable, Gradable, Rateable, Recordable, Reviewable, Scorable, Shareable

  belongs_to :user
  belongs_to :round, class_name: "Group::Round", optional: true

  # A group game may take 1st place from someone, who's told (Group::Challenge::Announceable)
  after_create_commit -> { round.challenge.played(self) }, if: -> { group? && round }

  # A level's practice; mixed practice, mixing every level up to the player's; a review of their recent mistakes;
  # a group challenge's round (Group::Challenge); a head to head's game against one other player (HeadToHead); or a
  # live game, played at the same time as others (LiveGame); or the Daily Tables Test, the same for everyone (DailyTest).
  # There was a daily challenge (once a day, mixed) until 21 October
  # 2026, and its games are kept. Only practice belongs to a level: earning stars and unlocking the next one
  MODES = %w[ practice challenge mixed review group head_to_head live daily ]

  validates :topic, inclusion: { in: Topic.keys }
  validates :mode, inclusion: { in: MODES }

  scope :in_topic, ->(topic) { where(topic: topic.key) }
  scope :at_level, ->(topic, level) { in_topic(topic).where(level: level, mode: "practice") }
  scope :daily_challenges, -> { where(mode: "challenge") }

  def practice? = mode == "practice"
  def daily_challenge? = mode == "challenge"
  def mixed? = mode == "mixed"
  def review? = mode == "review"
  def group? = mode == "group"
  def head_to_head? = mode == "head_to_head"
  def live? = mode == "live"
  def daily_test? = mode == "daily"

  def daily_test
    DailyTest.new(played_on) if daily_test?
  end

  # The live game it was played in
  def live_game
    LiveGame::Player.find_by(attempt_id: id)&.live_game
  end

  # The head to heads it's the go that counts in: just the one for a head to head game. A practice game can be sent
  # to several friends
  def head_to_heads
    HeadToHead.where(challenger_attempt_id: id).or(HeadToHead.where(opponent_attempt_id: id))
  end

  # A practice or mixed game can be sent to a friend to beat
  def sendable?
    (practice? || mixed?) && finished?
  end

  def topic_module
    Topic.find(topic)
  end

  def results_by_fact
    results.group_by { |result| fact_key(result) }
  end

  def mistakes
    results.reject { |result| result["correct"] }
  end

  def perfect?
    answered.positive? && correct == answered
  end

  private
    def fact_key(result)
      topic_module.fact_key(result)
    end
end
