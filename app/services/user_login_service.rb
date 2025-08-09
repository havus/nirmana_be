class UserLoginService
  class Result
    attr_reader :success, :user, :session, :errors

    def initialize(success:, user: nil, session: nil, errors: [])
      @success = success
      @user = user
      @session = session
      @errors = errors
    end

    def success?
      @success
    end
  end

  def self.call(login:, password:, ip_address: nil, user_agent: nil)
    new(login, password, ip_address, user_agent).call
  end

  def initialize(login, password, ip_address, user_agent)
    @login = login
    @password = password
    @ip_address = ip_address
    @user_agent = user_agent
  end

  def call
    return failure_result(['Login and password are required']) if @login.blank? || @password.blank?
    return failure_result(['Invalid credentials']) unless user&.authenticate(@password)
    return failure_result(['Account is deactivated']) unless user.active?
    
    ApplicationRecord.transaction do
      create_session!
      success_result
    end
  rescue StandardError => e
    Rails.logger.error "UserLoginService failed: #{e.message}"
    failure_result(['Login failed. Please try again.'])
  end

  private

  attr_reader :login, :password, :ip_address, :user_agent

  def user
    @user ||= find_user_by_login(@login)
  end

  def find_user_by_login(login_value)
    normalized_login = login_value.downcase.strip
    
    # Try to find by email first
    user = User.find_by(email: normalized_login)
    
    # If not found by email, try by username
    user ||= User.find_by(username: normalized_login)
    
    user
  end

  def create_session!
    @session = @user.user_sessions.create!(
      ip_address: @ip_address,
      user_agent: @user_agent,
      expires_at: 7.days.from_now
    )
  end

  def success_result
    Result.new(success: true, user: user, session: @session)
  end

  def failure_result(errors)
    Result.new(success: false, errors: errors)
  end
end
