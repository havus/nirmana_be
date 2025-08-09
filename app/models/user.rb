class User < ApplicationRecord
  has_secure_password

  # Enums
  enum :status, { inactive: 0, active: 1 }, default: :inactive

  # Associations
  has_many :password_reset_tokens, dependent: :destroy
  has_many :email_verification_tokens, dependent: :destroy
  has_many :user_sessions, dependent: :destroy
  has_many :projects, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: { case_sensitive: false }, 
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :uid, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true
  validates :first_name, length: { maximum: 100 }
  validates :last_name, length: { maximum: 100 }
  validates :phone, length: { maximum: 20 }
  validates :description, length: { maximum: 1000 }
  validates :avatar_url, length: { maximum: 500 }

  # Callbacks
  before_validation :generate_uid, on: :create
  before_save :normalize_email

  # Scopes
  scope :verified, -> { where.not(email_verified_at: nil) }

  # Instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def email_verified?
    email_verified_at.present?
  end

  def verify_email!
    update!(email_verified_at: Time.current, status: :active)
  end

  private

  def generate_uid
    self.uid = SecureRandom.uuid if uid.blank?
  end

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
end
