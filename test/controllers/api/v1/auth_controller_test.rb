require 'test_helper'

class Api::V1::AuthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
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
  test "should sign in with valid credentials" do
    post api_v1_sign_in_path, params: { 
      email: @user.email, 
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

  test "should return error for invalid email" do
    post api_v1_sign_in_path, params: { 
      email: 'nonexistent@example.com', 
      password: 'password123' 
    }
    
    assert_response :unauthorized
    
    response_body = JSON.parse(response.body)
    assert_equal 'Invalid credentials', response_body['error']
  end

  test "should return error for invalid password" do
    post api_v1_sign_in_path, params: { 
      email: @user.email, 
      password: 'wrongpassword' 
    }
    
    assert_response :unauthorized
    
    response_body = JSON.parse(response.body)
    assert_equal 'Invalid credentials', response_body['error']
  end

  test "should return error for missing email" do
    post api_v1_sign_in_path, params: { 
      password: 'password123' 
    }
    
    assert_response :bad_request
    
    response_body = JSON.parse(response.body)
    assert_equal 'Email and password are required', response_body['error']
  end

  test "should return error for missing password" do
    post api_v1_sign_in_path, params: { 
      email: @user.email 
    }
    
    assert_response :bad_request
    
    response_body = JSON.parse(response.body)
    assert_equal 'Email and password are required', response_body['error']
  end
end
