# The leagues a player owns and belongs to. Only a player with an account can make a league, so it isn't lost with
# a device; anyone can join one
module User::Leaguable
  extend ActiveSupport::Concern

  included do
    has_many :owned_leagues, class_name: "League", foreign_key: :owner_id, dependent: :destroy, inverse_of: :owner
    has_many :league_memberships, class_name: "League::Membership", dependent: :destroy
    has_many :leagues, through: :league_memberships
  end

  def can_make_leagues?
    persisted? && !guest?
  end
end
