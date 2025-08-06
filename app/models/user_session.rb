class UserSession < ApplicationRecord
  belongs_to :user

  # Validations
  validates :session_token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  # Callbacks
  before_validation :generate_session_token, :set_expiration
  after_initialize :touch_last_accessed

  # Scopes
  scope :active, -> { joins(:user).where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }

  # Class methods
  def self.create_for_user(user, ip_address: nil, user_agent: nil, expires_in: 7.days)
    create!(
      user: user,
      ip_address: ip_address,
      user_agent: user_agent,
      expires_at: expires_in.from_now
    )
  end

  def self.find_active_session(token)
    active.find_by(session_token: token)
  end

  def self.cleanup_expired
    expired.destroy_all
  end

  # Instance methods
  def expired?
    expires_at <= Time.current
  end

  def expire!
    update!(expires_at: Time.current)
  end

  def refresh!(expires_in: 7.days)
    return false if expired?
    
    update!(
      expires_at: expires_in.from_now,
      last_accessed_at: Time.current
    )
  end

  def expires_in
    return 0 if expired?
    (expires_at - Time.current).to_i
  end

  def time_since_last_access
    return 0 if last_accessed_at.nil?
    (Time.current - last_accessed_at).to_i
  end

  def browser_info
    return 'Unknown' if user_agent.blank?
    
    # Simple browser detection
    case user_agent
    when /Chrome/
      'Chrome'
    when /Firefox/
      'Firefox'
    when /Safari/
      'Safari'
    when /Edge/
      'Edge'
    else
      'Unknown Browser'
    end
  end

  private

  def generate_session_token
    loop do
      self.session_token = SecureRandom.urlsafe_base64(32)
      break unless self.class.exists?(session_token: session_token)
    end
  end

  def set_expiration
    self.expires_at ||= 7.days.from_now
  end

  def touch_last_accessed
    self.last_accessed_at ||= Time.current if persisted?
  end
end
