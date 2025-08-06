class UserRegistrationService
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Service result object
  class Result
    attr_reader :success, :user, :verification_token, :errors

    def initialize(success:, user: nil, verification_token: nil, errors: [])
      @success = success
      @user = user
      @verification_token = verification_token
      @errors = errors
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end

  # Attributes
  attribute :email, :string
  attribute :password, :string
  attribute :password_confirmation, :string
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :phone, :string

  # Validations
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }
  validates :password_confirmation, presence: true
  validate :passwords_match

  def self.call(params)
    service = new(params)
    service.call
  end

  def call
    return failure_result(errors.full_messages) unless valid?

    ApplicationRecord.transaction do
      create_user!
      create_verification_token!
      send_verification_email!
      
      success_result
    end
  rescue ActiveRecord::RecordInvalid => e
    failure_result([e.message])
  rescue StandardError => e
    Rails.logger.error "UserRegistrationService failed: #{e.message}"
    failure_result(["Registration failed. Please try again."])
  end

  private

  attr_reader :user, :verification_token

  def create_user!
    @user = User.create!(
      email: email,
      password: password,
      password_confirmation: password_confirmation,
      first_name: first_name,
      last_name: last_name,
      phone: phone
    )
  end

  def create_verification_token!
    @verification_token = EmailVerificationToken.create_for_user(@user)
  end

  def send_verification_email!
    UserMailer.email_verification(@user, @verification_token).deliver_later
  end

  def success_result
    Result.new(
      success: true,
      user: @user,
      verification_token: @verification_token
    )
  end

  def failure_result(error_messages)
    Result.new(
      success: false,
      errors: error_messages
    )
  end

  def passwords_match
    return if password.blank? || password_confirmation.blank?
    
    errors.add(:password_confirmation, "doesn't match password") if password != password_confirmation
  end
end
