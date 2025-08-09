class UserRetrievalService
  class Result
    attr_reader :success, :message, :data, :status

    def initialize(success:, message: nil, data: nil, status: nil)
      @success = success
      @message = message
      @data = data
      @status = status
    end

    def success?
      @success
    end
  end

  def initialize(user_uid)
    @user_uid = user_uid
  end

  def call
    return failure_result('User UID is required', :bad_request) if @user_uid.blank?

    begin
      user = find_user
      return failure_result('User not found', :not_found) unless user
      return failure_result('User account is not verified', :forbidden) unless user.email_verified?

      success_result('User retrieved successfully', user)
    rescue StandardError => e
      Rails.logger.error "UserRetrievalService failed: #{e.message}"
      failure_result('Failed to retrieve user. Please try again.', :internal_server_error)
    end
  end

  private

  def find_user
    User.find_by(uid: @user_uid)
  end

  def success_result(message, data)
    Result.new(success: true, message: message, data: data)
  end

  def failure_result(message, status)
    Result.new(success: false, message: message, status: status)
  end
end
