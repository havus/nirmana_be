require 'test_helper'

class Api::V1::AuthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      username: 'johndoe',
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'John',
      last_name: 'Doe'
    )
  end

  test "should verify email with valid token" do
    verification_token = EmailVerificationToken.create_for_user(@user)
    
    post api_v1_verify_email_path, params: { token: verification_token.token }
    
    assert_response :ok
    
    response_body = JSON.parse(response.body)
    assert_equal 'Email verified successfully', response_body['message']
    assert_equal @user.id, response_body['user']['id']
    assert_equal true, response_body['user']['email_verified']
    
    @user.reload
    assert @user.email_verified?
  end

  test "should return error for invalid token" do
    post api_v1_verify_email_path, params: { token: 'invalid_token' }
    
    assert_response :unprocessable_entity
    
    response_body = JSON.parse(response.body)
    assert_equal 'Invalid or expired token', response_body['error']
  end

  test "should return error for expired token" do
    verification_token = EmailVerificationToken.create_for_user(@user)
    verification_token.update!(expires_at: 1.hour.ago)
    
    post api_v1_verify_email_path, params: { token: verification_token.token }
    
    assert_response :unprocessable_entity
    
    response_body = JSON.parse(response.body)
    assert_equal 'Invalid or expired token', response_body['error']
  end

  test "should return error for missing token" do
    post api_v1_verify_email_path
    
    assert_response :bad_request
    
    response_body = JSON.parse(response.body)
    assert_equal 'Token is required', response_body['error']
  end

  test "should return error for already verified token" do
    verification_token = EmailVerificationToken.create_for_user(@user)
    verification_token.mark_as_verified! # Mark token as verified first
    
    post api_v1_verify_email_path, params: { token: verification_token.token }
    
    assert_response :unprocessable_entity
    
    response_body = JSON.parse(response.body)
    assert_equal 'Invalid or expired token', response_body['error']
  end

  # Sign In Tests
  test "should sign in with valid email credentials" do
    post api_v1_sign_in_path, params: { 
      login: @user.email, 
      password: 'password123' 
    }
    
    assert_response :ok
    
    response_body = JSON.parse(response.body)
    assert_equal 'Signed in successfully', response_body['message']
    assert_equal @user.id, response_body['user']['id']
    assert_equal @user.email, response_body['user']['email']
    assert_not_nil response_body['session']['token']
    assert_not_nil response_body['session']['expires_at']
  end

  test "should sign in with valid username credentials" do
    post api_v1_sign_in_path, params: { 
      login: @user.username, 
      password: 'password123' 
    }
    
    assert_response :ok
    
    response_body = JSON.parse(response.body)
    assert_equal 'Signed in successfully', response_body['message']
    assert_equal @user.id, response_body['user']['id']
    assert_equal @user.username, response_body['user']['username']
    assert_equal @user.email, response_body['user']['email']
    assert_not_nil response_body['session']['token']
    assert_not_nil response_body['session']['expires_at']
  end

  test "should return error for invalid login" do
    post api_v1_sign_in_path, params: { 
      login: 'nonexistent@example.com', 
      password: 'password123' 
    }
    
    assert_response :unauthorized
    
    response_body = JSON.parse(response.body)
    assert_equal 'Invalid credentials', response_body['error']
  end

  test "should return error for invalid password" do
    post api_v1_sign_in_path, params: { 
      login: @user.email, 
      password: 'wrongpassword' 
    }
    
    assert_response :unauthorized
    
    response_body = JSON.parse(response.body)
    assert_equal 'Invalid credentials', response_body['error']
  end

  test "should return error for missing login" do
    post api_v1_sign_in_path, params: { 
      password: 'password123' 
    }
    
    assert_response :bad_request
    
    response_body = JSON.parse(response.body)
    assert_equal 'Login and password are required', response_body['error']
  end

  test "should return error for missing password" do
    post api_v1_sign_in_path, params: { 
      login: @user.email 
    }
    
    assert_response :bad_request
    
    response_body = JSON.parse(response.body)
    assert_equal 'Login and password are required', response_body['error']
  end

  test "should change password with valid credentials" do
    # Create a user session for authentication
    session = UserSession.create_for_user(@user)
    headers = { 'Authorization' => "Bearer #{session.session_token}" }

    post api_v1_change_password_path, 
         params: { 
           current_password: 'password123',
           new_password: 'NewPassword456',
           new_password_confirmation: 'NewPassword456'
         },
         headers: headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    assert_equal 'Password changed successfully', response_body['message']
    assert_equal @user.id, response_body['user']['id']

    # Verify old password no longer works and new password works
    @user.reload
    assert_not @user.authenticate('password123')
    assert @user.authenticate('NewPassword456')
  end

  test "should reject password change with incorrect current password" do
    session = UserSession.create_for_user(@user)
    headers = { 'Authorization' => "Bearer #{session.session_token}" }

    post api_v1_change_password_path,
         params: {
           current_password: 'wrongpassword',
           new_password: 'NewPassword456',
           new_password_confirmation: 'NewPassword456'
         },
         headers: headers

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert_equal 'Password change failed', response_body['error']
    assert_includes response_body['details'], 'Current password is incorrect'
  end

  test "should reject password change with mismatched confirmation" do
    session = UserSession.create_for_user(@user)
    headers = { 'Authorization' => "Bearer #{session.session_token}" }

    post api_v1_change_password_path,
         params: {
           current_password: 'password123',
           new_password: 'NewPassword456',
           new_password_confirmation: 'DifferentPassword'
         },
         headers: headers

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert_equal 'Password change failed', response_body['error']
    assert_includes response_body['details'], 'New password and confirmation do not match'
  end

  test "should reject password change without authentication" do
    post api_v1_change_password_path,
         params: {
           current_password: 'password123',
           new_password: 'NewPassword456',
           new_password_confirmation: 'NewPassword456'
         }

    assert_response :unauthorized

    response_body = JSON.parse(response.body)
    assert_equal 'Authorization token required', response_body['error']
  end

  test "should reject password change with invalid token" do
    headers = { 'Authorization' => 'Bearer invalid_token' }

    post api_v1_change_password_path,
         params: {
           current_password: 'password123',
           new_password: 'NewPassword456',
           new_password_confirmation: 'NewPassword456'
         },
         headers: headers

    assert_response :unauthorized

    response_body = JSON.parse(response.body)
    assert_equal 'Invalid or expired token', response_body['error']
  end

  test "should send forgot password email for existing user" do
    post api_v1_forgot_password_path, params: { email: @user.email }

    assert_response :ok

    response_body = JSON.parse(response.body)
    assert_equal 'If an account with that email exists, a password reset link has been sent.', response_body['message']

    # Check that a password reset token was created
    assert_not_nil PasswordResetToken.find_by(user: @user)
  end

  test "should return same message for non-existing user email" do
    post api_v1_forgot_password_path, params: { email: 'nonexistent@example.com' }

    assert_response :ok

    response_body = JSON.parse(response.body)
    assert_equal 'If an account with that email exists, a password reset link has been sent.', response_body['message']
  end

  test "should reject forgot password request without email" do
    post api_v1_forgot_password_path, params: {}

    assert_response :bad_request

    response_body = JSON.parse(response.body)
    assert_equal 'Email is required', response_body['error']
  end

  test "should reject forgot password request with blank email" do
    post api_v1_forgot_password_path, params: { email: '' }

    assert_response :bad_request

    response_body = JSON.parse(response.body)
    assert_equal 'Email is required', response_body['error']
  end

  test "should reset password with valid token" do
    reset_token = PasswordResetToken.create_for_user(@user)

    post api_v1_reset_password_path,
         params: {
           token: reset_token.token,
           new_password: 'NewPassword456',
           new_password_confirmation: 'NewPassword456'
         }

    assert_response :ok

    response_body = JSON.parse(response.body)
    assert_equal 'Password has been reset successfully', response_body['message']
    assert_equal @user.id, response_body['user']['id']

    # Verify new password works and old doesn't
    @user.reload
    assert @user.authenticate('NewPassword456')
    assert_not @user.authenticate('password123')

    # Verify token is used
    reset_token.reload
    assert reset_token.used?
  end

  test "should reject password reset with invalid token" do
    post api_v1_reset_password_path,
         params: {
           token: 'invalid_token',
           new_password: 'NewPassword456',
           new_password_confirmation: 'NewPassword456'
         }

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert_equal 'Password reset failed', response_body['error']
    assert_includes response_body['details'], 'Invalid or expired reset token'
  end

  test "should reject password reset with mismatched passwords" do
    reset_token = PasswordResetToken.create_for_user(@user)

    post api_v1_reset_password_path,
         params: {
           token: reset_token.token,
           new_password: 'NewPassword456',
           new_password_confirmation: 'DifferentPassword'
         }

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert_equal 'Password reset failed', response_body['error']
    assert_includes response_body['details'], 'New password and confirmation do not match'
  end
end
