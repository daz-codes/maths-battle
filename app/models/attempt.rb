class Attempt < ApplicationRecord
  include Badgeable, Gradable, Medallable, Recordable, Reviewable, Shareable, Starrable

  belongs_to :user
  belongs_to :round, class_name: "Group::Round", optional: true

  # A group game may take 1st place from someone, who's told (Group::Challenge::Announceable)
  after_create_commit -> { round.challenge.played(self) }, if: -> { group? && round }

  # A level's practice; the daily challenge, mixing every level up to the player's; mixed practice, the same mix
  # as often as they like once the day's challenge is done; a review of their recent mistakes; or a group
  # challenge's round (Group::Challenge). Only practice belongs to a level: earning medals and unlocking the next one
  MODES = %w[ practice challenge mixed review group ]

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
    answered.positive? && score == answered
  end

  private
    def fact_key(result)
      topic_module.fact_key(result)
    end
end
