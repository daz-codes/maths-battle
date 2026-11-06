# Joining a live game's lobby from its link or its code, before it starts, while there's room. The code is five
# letters and digits that can't be mistaken for each other, like a group's but shorter, so it's quick to read out
# and type in
module LiveGame::Joinable
  extend ActiveSupport::Concern

  MAX_PLAYERS = 8
  CODE_LENGTH = 5
  # A lobby no one starts closes after this long
  LOBBY_TIME = 30.minutes

  included do
    before_validation :assign_code, on: :create
  end

  class_methods do
    def find_by_code(code)
      find_by(code: code.to_s.upcase.delete("^A-Z0-9"))
    end
  end

  def joinable?
    !started? && created_at > LOBBY_TIME.ago && players.count < MAX_PLAYERS
  end

  # True once they're in, whether they've just joined or already were
  def join(user)
    with_lock do
      return true if player?(user)
      return false unless joinable?

      players.create!(user: user)
    end
    broadcast_lobby
    true
  end

  private
    def assign_code
      self.code ||= loop do
        code = Array.new(CODE_LENGTH) { League::Joinable::CODE_CHARACTERS.sample }.join
        break code unless LiveGame.exists?(code: code)
      end
    end
end
