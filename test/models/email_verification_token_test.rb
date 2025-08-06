require 'test_helper'

class EmailVerificationTokenTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'John',
      last_name: 'Doe'
    )
  end

  test "should create valid token for user" do
    token = EmailVerificationToken.create_for_user(@user)
    
    assert token.persisted?
    assert_equal @user, token.user
    assert token.valid_token?
    assert_not token.verified?
    assert_not token.expired?
  end

  test "should invalidate existing tokens when creating new one" do
    old_token = EmailVerificationToken.create_for_user(@user)
    new_token = EmailVerificationToken.create_for_user(@user)
    
    old_token.reload
    assert old_token.invalidated?
    assert_not new_token.invalidated?
  end

  test "should find valid token" do
    token = EmailVerificationToken.create_for_user(@user)
    found_token = EmailVerificationToken.find_valid_token(token.token)
    
    assert_equal token, found_token
  end

  test "should not find expired token" do
    token = EmailVerificationToken.create_for_user(@user)
    token.update!(expires_at: 1.hour.ago)
    
    found_token = EmailVerificationToken.find_valid_token(token.token)
    assert_nil found_token
  end

  test "should not find verified token" do
    token = EmailVerificationToken.create_for_user(@user)
    token.mark_as_verified!
    
    found_token = EmailVerificationToken.find_valid_token(token.token)
    assert_nil found_token
  end

  test "should mark token as verified" do
    token = EmailVerificationToken.create_for_user(@user)
    
    result = token.mark_as_verified!
    
    assert result
    assert token.verified?
    assert token.verified_at.present?
  end

  test "should not mark expired token as verified" do
    token = EmailVerificationToken.create_for_user(@user)
    token.update!(expires_at: 1.hour.ago)
    
    result = token.mark_as_verified!
    
    assert_not result
    assert_not token.verified?
  end

  test "should not mark already verified token as verified again" do
    token = EmailVerificationToken.create_for_user(@user)
    token.mark_as_verified!
    original_verified_at = token.verified_at
    
    result = token.mark_as_verified!
    
    assert_not result
    assert_equal original_verified_at, token.verified_at
  end

  test "should check token validity" do
    token = EmailVerificationToken.create_for_user(@user)
    assert token.valid_token?
    
    token.update!(expires_at: 1.hour.ago)
    assert_not token.valid_token?
    
    token.update!(expires_at: 1.hour.from_now, verified_at: Time.current)
    assert_not token.valid_token?
  end

  test "should calculate expires_in correctly" do
    token = EmailVerificationToken.create_for_user(@user)
    
    # Should be close to 24 hours (86400 seconds), allowing for small timing differences
    assert_in_delta 86400, token.expires_in, 10
    
    token.update!(expires_at: 1.hour.ago)
    assert_equal 0, token.expires_in
  end
end
