class ResetPasswordService
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

  def self.call(token:, new_password:, new_password_confirmation:)
    new.call(token, new_password, new_password_confirmation)
  end

  def call(token, new_password, new_password_confirmation)
    return failure_result(['Token is required']) if token.blank?
    return failure_result(['New password is required']) if new_password.blank?
    return failure_result(['New password confirmation is required']) if new_password_confirmation.blank?
    return failure_result(['New password and confirmation do not match']) if new_password != new_password_confirmation

    reset_token = PasswordResetToken.find_valid_token(token)
    return failure_result(['Invalid or expired reset token']) unless reset_token

    # Validate new password strength
    password_errors = validate_password_strength(new_password)
    return failure_result(password_errors) if password_errors.any?

    user = reset_token.user

    ApplicationRecord.transaction do
      user.update!(password: new_password)
      reset_token.use!
      # Optionally, invalidate all existing sessions
      user.user_sessions.destroy_all
      Result.new(success: true, user: user)
    end
  rescue ActiveRecord::RecordInvalid => e
    failure_result(e.record.errors.full_messages)
  rescue StandardError => e
    Rails.logger.error "Password reset failed: #{e.message}"
    failure_result(['Password reset failed. Please try again.'])
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

  def failure_result(errors)
    Result.new(success: false, errors: Array(errors))
  end
end
