# A family's or a class's own league: an owner makes it, others join with its code, and its table is each member's
# best game today. Every game counts, solo or battle, in every league its player is in, and in the world league,
# which is everyone's (League::Standings). Leagues start again every day, at midnight in London for everyone, so a
# day's table is the same wherever it's looked at
class League < ApplicationRecord
  include Joinable

  NAME_LENGTH = 40
  ZONE = "London"

  belongs_to :owner, class_name: "User"
  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user

  validates :name, presence: true, length: { maximum: NAME_LENGTH }

  # The owner is a member too, so the league is theirs to see
  after_create { memberships.create!(user: owner) }

  # The leagues' day a time falls on
  def self.day(time = Time.current)
    time.in_time_zone(ZONE).to_date
  end

  def self.today
    day
  end

  # When today's tables start again
  def self.resets_at
    (today + 1).in_time_zone(ZONE)
  end

  def self.world(day = today)
    Standings.new(day: day)
  end

  def standings(day = League.today)
    Standings.new(day: day, users: members)
  end

  def owned_by?(user)
    user.present? && owner_id == user.id
  end
end
