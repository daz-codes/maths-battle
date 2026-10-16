class Session < ApplicationRecord
  LIFETIME = 90.days

  belongs_to :user

  scope :active, -> { where(created_at: LIFETIME.ago..) }

  def expires_at
    created_at + LIFETIME
  end
end
