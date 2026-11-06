# Someone looking for a battle with anyone, while their Find a match page is open (MatchmakingChannel). As soon as
# there are two or more, up to MAX_PLAYERS of those waiting longest are put in a battle together, which starts at
# once. Leaving the page takes them out. Writes to SQLite happen one at a time, so two people arriving together
# can't both take the same players
class MatchRequest < ApplicationRecord
  MAX_PLAYERS = 4
  # A request left behind by a page that closed without saying so isn't matched
  STALE_AFTER = 2.minutes

  belongs_to :user

  scope :waiting, -> { where(updated_at: STALE_AFTER.ago..).order(:created_at, :id) }

  # The battle they're in, if there are enough now
  def self.enter(user)
    transaction do
      find_or_initialize_by(user: user).tap { |request| request.new_record? ? request.save! : request.touch }
      match!
    end
  end

  def self.leave(user)
    where(user: user).delete_all
  end

  def self.waiting_count
    waiting.count
  end

  def self.match!
    requests = waiting.includes(:user).limit(MAX_PLAYERS).to_a
    return if requests.size < 2

    where(id: requests.map(&:id)).delete_all
    LiveGame.match!(requests.map(&:user))
  end
end
