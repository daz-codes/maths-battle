# The badges a player has collected. Games earn them as they're saved (Attempt::Badgeable)
module User::Badgeable
  extend ActiveSupport::Concern

  included do
    has_many :badges, dependent: :destroy
  end

  # Earned badges by kind, for showing every badge with the ones earned picked out
  def badges_by_kind
    @badges_by_kind ||= badges.index_by(&:kind)
  end

  # Works through every game in the order played, so badges added later reach players who already earned them
  def catch_up_badges!
    attempts.order(:played_at, :id).each(&:award_badges)
  end
end
