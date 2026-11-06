# Joining a league with its code, like K7Q2MX: six letters and digits that can't be mistaken for each other
# (no 0 or O, 1 or I), so it can be read out to a class or family, or typed from a screen
module League::Joinable
  extend ActiveSupport::Concern

  CODE_CHARACTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".chars
  CODE_LENGTH = 6
  MAX_MEMBERS = 60

  class Full < StandardError; end
  class InvalidCode < StandardError; end

  included do
    before_validation :assign_join_code, on: :create
  end

  class_methods do
    # As typed: spaces and case don't matter
    def find_by_code(code)
      find_by(join_code: code.to_s.upcase.delete("^A-Z0-9"))
    end
  end

  # Check the submitted code again under the lock, so a removal or code change also stops a join under way.
  # Internal callers can omit the code; public joins must supply the submitted one
  def join(user, code: join_code)
    with_lock do
      raise InvalidCode unless self.class.find_by_code(code)&.id == id

      memberships.find_or_create_by!(user: user)
    end
  rescue ActiveRecord::RecordInvalid
    raise Full if full?
    raise
  end

  # Existing players stay joined. Anyone invited back, including someone removed by mistake, uses the new code
  def renew_join_code!
    with_lock { update!(join_code: unused_join_code) }
  end

  def remove(membership)
    with_lock do
      memberships.find(membership.id).destroy!
      update!(join_code: unused_join_code)
    end
  end

  def member?(user)
    user.present? && memberships.exists?(user: user)
  end

  def full?
    memberships.count >= MAX_MEMBERS
  end

  private
    def assign_join_code
      self.join_code ||= unused_join_code
    end

    def unused_join_code
      loop do
        code = Array.new(CODE_LENGTH) { CODE_CHARACTERS.sample }.join
        break code unless League.exists?(join_code: code)
      end
    end
end
