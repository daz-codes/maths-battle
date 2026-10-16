# Guests have no username, so a guest whose device forgets its session (cleared cookies, a new phone) can never
# get back to their account. Those accounts would pile up forever, so ones nobody has used in a long while are
# deleted every night (see config/recurring.yml). A guest who has played is kept a year, in case they come back
# after a long break; one who never played, like an account made just by saving settings, only a month
module User::Abandonable
  extend ActiveSupport::Concern

  PLAYED_GUESTS_KEPT_FOR = 1.year
  UNPLAYED_GUESTS_KEPT_FOR = 30.days

  included do
    scope :guests, -> { where(username: nil) }
    scope :abandoned_guests, -> { unplayed_guests_since(UNPLAYED_GUESTS_KEPT_FOR.ago).or(guests_idle_since(PLAYED_GUESTS_KEPT_FOR.ago)) }

    scope :unplayed_guests_since, ->(time) { guests.where(updated_at: ...time).where.not(id: Attempt.select(:user_id)) }
    scope :guests_idle_since, ->(time) { guests.where(updated_at: ...time).where.not(id: Attempt.where(created_at: time..).select(:user_id)) }
  end

  class_methods do
    # Their games, stats, sessions and picture go with them
    def destroy_abandoned_guests
      abandoned_guests.find_each(&:destroy)
    end
  end
end
