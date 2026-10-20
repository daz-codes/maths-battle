# Players who compete on the same questions: an owner makes the group, others join it with its code, and the
# owner sets challenges (Group::Challenge) with a leaderboard each. Invite only: there's no way to find a group
# without its code, and players see names and scores, never other players' pictures
class Group < ApplicationRecord
  include Joinable

  NAME_LENGTH = 40

  belongs_to :owner, class_name: "User"
  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :challenges, dependent: :destroy

  validates :name, presence: true, length: { maximum: NAME_LENGTH }

  # The owner is a member too, so the group is theirs to see
  after_create { memberships.create!(user: owner) }

  def owned_by?(user)
    user.present? && owner_id == user.id
  end

  # The group's day goes by its owner's time zone, so everyone gets the same questions on the same day
  def today
    owner.today
  end

  def week
    today.all_week
  end
end
