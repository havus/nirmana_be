class PasswordResetService
  class Result
    attr_reader :success, :user, :reset_token, :errors

    def initialize(success:, user: nil, reset_token: nil, errors: [])
      @success = success
      @user = user
      @reset_token = reset_token
      @errors = errors
    end

    def success?
      @success
    end
  end

  def self.call(email:)
    new(email).call
  end

  def initialize(email)
    @email = email
  end

  def call
    return failure_result(['User not found']) unless user
    return failure_result(['Account is deactivated']) unless user.active?

    ApplicationRecord.transaction do
      create_reset_token!
      send_reset_email!
      success_result
    end
  rescue StandardError => e
    Rails.logger.error "PasswordResetService failed: #{e.message}"
    failure_result(['Password reset failed. Please try again.'])
  end

  private

  attr_reader :email

  def user
    @user ||= User.find_by(email: @email.downcase.strip)
  end

  def create_reset_token!
    @reset_token = PasswordResetToken.create_for_user(user)
  end

  def send_reset_email!
    UserMailer.password_reset(user, @reset_token).deliver_later
  end

  def success_result
    Result.new(success: true, user: user, reset_token: @reset_token)
  end

  def failure_result(errors)
    Result.new(success: false, errors: errors)
  end
end
