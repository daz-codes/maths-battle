# What a group's owner sets: a topic and level, for a while or until the owner closes it. Everyone in the group
# plays the same questions (Group::Round): one set for a one-off challenge, or a fresh set each day for an every
# day one, the day going by the group's time zone. Only each player's first go at a round counts (Rankable)
class Group::Challenge < ApplicationRecord
  include Announceable, Rankable

  # How long a challenge runs, as the owner picks it; nil runs until they close it
  DURATIONS = { "1 day" => 1.day, "3 days" => 3.days, "1 week" => 1.week, "Until I close it" => nil }

  belongs_to :group
  has_many :rounds, dependent: :destroy

  validates :topic, inclusion: { in: Topic.keys }
  validate :level_in_topic

  after_create :round

  scope :running, -> { where(closed_at: nil).merge(where(ends_at: nil).or(where(ends_at: Time.current..))) }

  def topic_module
    Topic.find(topic)
  end

  # A closed daily challenge keeps its last round. Only open challenges can make a fresh one
  def round
    return display_round_scope.first if daily? && !open?

    day = daily? ? group.today : nil
    rounds.find_or_create_by!(day: day) { |round| round.questions = Group::Round.questions_for(self) }
  end

  # Also used to load just the displayed rounds for a list, without their question JSON
  def display_round_scope
    if daily? && !open?
      last_round = rounds.where(day: ..ended_at.in_time_zone(group.owner.time_zone).to_date).order(day: :desc).limit(1)
      rounds.where(id: last_round.select(:id))
    else
      rounds.where(day: daily? ? group.today : nil)
    end
  end

  def leaderboard_day
    open? ? group.today : (round&.day || ended_at.in_time_zone(group.owner.time_zone).to_date)
  end

  def leaderboard_week
    leaderboard_day.all_week
  end

  def open?
    closed_at.nil? && (ends_at.nil? || ends_at.future?)
  end

  def close!
    update!(closed_at: Time.current) if open?
  end

  # When it stopped counting: when it was closed or ran out, if it has
  def ended_at
    [ closed_at, ends_at ].compact.min
  end

  # Everyone in the group, but the owner only if they chose to play
  def players
    group.members.then { |members| owner_plays ? members : members.where.not(id: group.owner_id) }
  end

  def player?(user)
    user.present? && players.exists?(user.id)
  end

  def playable_by?(user)
    open? && player?(user)
  end

  # Today's round, for an every day challenge
  def played_by?(user)
    display_round_scope.joins(:attempts).where(attempts: { user_id: user.id }).exists?
  end

  def title
    "#{topic_module.title} · Level #{level}"
  end

  private
    def level_in_topic
      errors.add(:level, :inclusion) unless topic_module&.level(level)
    end
end
