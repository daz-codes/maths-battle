# An award a player has earned, and the game that earned it. What each kind is called, and the rule that earns
# it, is in Badge::Catalogued; most rules are asked of the game (Attempt::Badgeable), and a few are given when
# something happens: winning a battle (LiveGame::Startable) or joining a league (League::Membership)
class Badge < ApplicationRecord
  include Catalogued

  belongs_to :user
  belongs_to :attempt, optional: true

  validates :kind, inclusion: { in: ->(_) { keys } }

  # Earned once: nil if they already have it
  def self.award(user, kind, attempt: nil, at: Time.current)
    return if user.badges.exists?(kind: kind)

    user.badges.create!(kind: kind, attempt: attempt, earned_at: at)
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
