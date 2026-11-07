# A player in a league. The owner is one too
class League::Membership < ApplicationRecord
  belongs_to :league
  belongs_to :user

  validates :user_id, uniqueness: { scope: :league_id }
  validate :room_in_league, on: :create

  after_create_commit { Badge.award(user, "team_player") }

  private
    def room_in_league
      errors.add(:league, "is full") if league.memberships.count >= League::MAX_MEMBERS
    end
end
