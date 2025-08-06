class PasswordResetToken < ApplicationRecord
  belongs_to :user

  # Validations
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  # Callbacks
  before_create :generate_token
  before_create :set_expiration

  # Scopes
  scope :valid, -> { where('expires_at > ? AND used_at IS NULL', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }
  scope :used, -> { where.not(used_at: nil) }

  # Class methods
  def self.create_for_user(user)
    create!(user: user)
  end

  def self.find_valid_token(token)
    valid.find_by(token: token)
  end

  # Instance methods
  def valid_token?
    expires_at > Time.current && used_at.nil?
  end

  def expired?
    expires_at <= Time.current
  end

  def used?
    used_at.present?
  end

  def use!
    return false if expired? || used?
    
    update!(used_at: Time.current)
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
    self.expires_at = 1.hour.from_now
  end
end
