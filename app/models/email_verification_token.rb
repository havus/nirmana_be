class EmailVerificationToken < ApplicationRecord
  belongs_to :user

  # Validations
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  # Callbacks
  before_validation :generate_token, :set_expiration

  # Scopes
  scope :valid, -> { where('expires_at > ? AND verified_at IS NULL AND invalidated_at IS NULL', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :verified, -> { where.not(verified_at: nil) }
  scope :invalidated, -> { where.not(invalidated_at: nil) }

  # Class methods
  def self.create_for_user(user)
    # Invalidate any existing valid tokens (keeps history)
    where(user: user).valid.update_all(invalidated_at: Time.current)
    create!(user: user)
  end

  def self.find_valid_token(token)
    valid.find_by(token: token)
  end

  # Instance methods
  def valid_token?
    expires_at > Time.current && verified_at.nil? && invalidated_at.nil?
  end

  def expired?
    expires_at <= Time.current
  end

  def verified?
    verified_at.present?
  end

  def invalidated?
    invalidated_at.present?
  end

  def verify!
    return false if expired? || verified?
    
    transaction do
      update!(verified_at: Time.current)
      user.verify_email!
    end
  end

  def expires_in
    return 0 if expired?
    (expires_at - Time.current).to_i
  end

  private

  def generate_token
    loop do
      self.token = SecureRandom.urlsafe_base64(32)
      break unless self.class.exists?(token: token)
    end
  end

  def set_expiration
    self.expires_at = 24.hours.from_now
  end
end
