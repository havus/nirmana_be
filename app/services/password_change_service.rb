class PasswordChangeService
  class Result
    attr_reader :success, :user, :errors

    def initialize(success:, user: nil, errors: [])
      @success = success
      @user = user
      @errors = errors
    end

    def success?
      @success
    end
  end

  def self.call(user:, current_password:, new_password:, new_password_confirmation:)
    new(user, current_password, new_password, new_password_confirmation).call
  end

  def initialize(user, current_password, new_password, new_password_confirmation)
    @user = user
    @current_password = current_password
    @new_password = new_password
    @new_password_confirmation = new_password_confirmation
  end

  def call
    return failure_result(['User is required']) unless @user
    return failure_result(['Current password is required']) if @current_password.blank?
    return failure_result(['New password is required']) if @new_password.blank?
    return failure_result(['New password confirmation is required']) if @new_password_confirmation.blank?
    return failure_result(['New password and confirmation do not match']) if @new_password != @new_password_confirmation
    return failure_result(['Current password is incorrect']) unless @user.authenticate(@current_password)
    return failure_result(['New password must be different from current password']) if @current_password == @new_password

    # Validate new password strength (you can customize these rules)
    password_errors = validate_password_strength(@new_password)
    return failure_result(password_errors) if password_errors.any?

    ApplicationRecord.transaction do
      @user.update!(password: @new_password)
      # Optionally, you can invalidate all existing sessions except the current one
      # @user.user_sessions.where.not(id: current_session_id).destroy_all
      success_result
    end
  rescue ActiveRecord::RecordInvalid => e
    failure_result(e.record.errors.full_messages)
  rescue StandardError => e
    Rails.logger.error "PasswordChangeService failed: #{e.message}"
    failure_result(['Password change failed. Please try again.'])
  end

  private

  def validate_password_strength(password)
    errors = []
    errors << 'New password must be at least 8 characters long' if password.length < 8
    errors << 'New password must contain at least one uppercase letter' unless password.match?(/[A-Z]/)
    errors << 'New password must contain at least one lowercase letter' unless password.match?(/[a-z]/)
    errors << 'New password must contain at least one number' unless password.match?(/\d/)
    errors
  end

  def success_result
    Result.new(success: true, user: @user)
  end

  def failure_result(errors)
    Result.new(success: false, errors: Array(errors))
  end
end
