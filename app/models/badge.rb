# A badge a player has earned, and the game that earned it. What each kind is called, and the rule
# that earns it, is in Badge::Catalogued; the rules themselves are asked of the game (Attempt::Badgeable)
class Badge < ApplicationRecord
  include Catalogued

  belongs_to :user
  belongs_to :attempt, optional: true

  validates :kind, inclusion: { in: ->(_) { keys } }
end
