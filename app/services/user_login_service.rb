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

  def self.call(email:, password:, ip_address: nil, user_agent: nil)
    new(email, password, ip_address, user_agent).call
  end

  def initialize(email, password, ip_address, user_agent)
    @email = email
    @password = password
    @ip_address = ip_address
    @user_agent = user_agent
  end

  def call
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

  attr_reader :email, :password, :ip_address, :user_agent

  def user
    @user ||= User.find_by(email: @email.downcase.strip)
  end

  def create_session!
    @session = user.create_session!(
      ip_address: @ip_address,
      user_agent: @user_agent
    )
  end

  def success_result
    Result.new(success: true, user: user, session: @session)
  end

  def failure_result(errors)
    Result.new(success: false, errors: errors)
  end
end
