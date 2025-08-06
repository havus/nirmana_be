require 'test_helper'

class EmailVerificationServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'John',
      last_name: 'Doe'
    )
  end

  test "should successfully verify email with valid token" do
    verification_token = EmailVerificationToken.create_for_user(@user)
    
    result = EmailVerificationService.call(token: verification_token.token)
    
    assert result.success?
    assert_equal @user.id, result.user.id
    assert result.user.email_verified?
    assert result.verification_token.verified?
  end

  test "should fail with invalid token" do
    result = EmailVerificationService.call(token: 'invalid_token')
    
    assert_not result.success?
    assert_includes result.errors, 'Invalid or expired token'
  end

  test "should fail with expired token" do
    verification_token = EmailVerificationToken.create_for_user(@user)
    verification_token.update!(expires_at: 1.hour.ago)
    
    result = EmailVerificationService.call(token: verification_token.token)
    
    assert_not result.success?
    assert_includes result.errors, 'Invalid or expired token'
  end

  test "should fail with blank token" do
    result = EmailVerificationService.call(token: '')
    
    assert_not result.success?
    assert_includes result.errors, "Token can't be blank"
  end

  test "should fail with nil token" do
    result = EmailVerificationService.call(token: nil)
    
    assert_not result.success?
    assert_includes result.errors, "Token can't be blank"
  end

  test "should fail with already verified token" do
    verification_token = EmailVerificationToken.create_for_user(@user)
    verification_token.mark_as_verified!
    
    result = EmailVerificationService.call(token: verification_token.token)
    
    assert_not result.success?
    assert_includes result.errors, 'Invalid or expired token'
  end

  test "should not verify user email if token marking fails" do
    verification_token = EmailVerificationToken.create_for_user(@user)
    
    # Mock the mark_as_verified! method to return false
    EmailVerificationToken.any_instance.stubs(:mark_as_verified!).returns(false)
    
    result = EmailVerificationService.call(token: verification_token.token)
    
    assert_not result.success?
    assert_includes result.errors, 'Failed to verify email'
    
    @user.reload
    assert_not @user.email_verified?
  end
end
