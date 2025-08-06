class EmailVerificationService
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

  attribute :token, :string

  validates :token, presence: true

  def initialize(token:)
    @token = token
    super(token: token)
  end

  def call
    return Result.new(success: false, errors: errors.full_messages) unless valid?

    verification_token = EmailVerificationToken.find_valid_token(@token)

    if verification_token.nil?
      return Result.new(
        success: false, 
        errors: ['Invalid or expired token']
      )
    end

    begin
      ActiveRecord::Base.transaction do
        # Mark the token as verified
        verification_token.mark_as_verified!
        
        # Verify the user's email
        verification_token.user.verify_email!
        
        Result.new(
          success: true,
          user: verification_token.user,
          verification_token: verification_token
        )
      end
    rescue => e
      Result.new(
        success: false,
        errors: ['Failed to verify email']
      )
    end
  end

  def self.call(token:)
    new(token: token).call
  end
end
