# Guests play without signing up, so they have no username or password until they register.
# Registering fills those in on the same account, keeping the guest's streak and history
module User::Registerable
  extend ActiveSupport::Concern

  NAME_LENGTH = 30

  USERNAME_FORMAT = /\A[a-z0-9_]+\z/
  MIN_PASSWORD_LENGTH = 15

  included do
    has_secure_password validations: false

    normalizes :username, with: ->(username) { username.strip.downcase.presence }
    normalizes :name, with: ->(name) { name.squish.presence }

    with_options if: :registering? do
      validates :username, presence: true, uniqueness: true,
        format: { with: USERNAME_FORMAT, message: "can only use letters, numbers and _", allow_blank: true },
        length: { in: 3..20, allow_blank: true }
      validate :password_set
    end
    validates :name, presence: true, on: :registration
    validates :name, length: { maximum: NAME_LENGTH }
    validates :password, length: { in: MIN_PASSWORD_LENGTH..72 }, allow_nil: true
    validate :password_fits_bcrypt
  end

  class_methods do
    def create_guest!
      create!
    end
  end

  def guest?
    username.nil?
  end

  def register(attributes)
    assign_attributes(attributes)
    save(context: :registration)
  end

  def display_name
    name || username
  end

  private
    def registering?
      username.present? || validation_context == :registration
    end

    def password_set
      errors.add(:password, :blank) if password_digest.blank?
    end

    def password_fits_bcrypt
      errors.add(:password, :password_too_long) if password && password.bytesize > ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED
    end
end
