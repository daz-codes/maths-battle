# The groups a player owns and belongs to, and the group challenges waiting for them. Only a player with an
# account can make a group, so it isn't lost with a device; anyone can join one
module User::Groupable
  extend ActiveSupport::Concern

  included do
    has_many :owned_groups, class_name: "Group", foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner
    has_many :group_memberships, class_name: "Group::Membership", dependent: :destroy
    has_many :groups, through: :group_memberships
  end

  def can_make_groups?
    persisted? && !guest?
  end

  # Open challenges in their groups that they play and haven't yet, newest first
  def group_challenges_to_play
    return [] unless persisted?

    challenges = Group::Challenge.running.where(group: groups).includes(group: :owner).order(created_at: :desc)
    Group::Challenge::Listing.new(challenges, user: self).waiting_challenges
  end
end
