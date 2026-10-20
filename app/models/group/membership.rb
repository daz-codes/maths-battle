# A player in a group. The owner is one too
class Group::Membership < ApplicationRecord
  belongs_to :group
  belongs_to :user

  validates :user_id, uniqueness: { scope: :group_id }
  validate :room_in_group, on: :create

  private
    def room_in_group
      errors.add(:group, "is full") if group.memberships.count >= Group::MAX_MEMBERS
    end
end
