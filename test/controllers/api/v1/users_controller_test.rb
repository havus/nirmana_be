require 'test_helper'

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'John',
      last_name: 'Doe',
      phone: '1234567890',
      description: 'Test user description',
      date_of_birth: '1990-01-15'
    )
    @user.verify_email!

    @other_user = User.create!(
      email: 'other@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Jane',
      last_name: 'Smith',
      phone: '0987654321',
      description: 'Another test user',
      date_of_birth: '1985-05-20'
    )
    @other_user.verify_email!

    @session = @user.user_sessions.create!(
      token_digest: BCrypt::Password.create('test_token'),
      expires_at: 1.week.from_now
    )

    @headers = { 'Authorization' => 'Bearer test_token' }
  end

  # === SHOW ACTION TESTS ===

  test 'should get user by uid without authentication' do
    get api_v1_user_path(@user.uid)

    assert_response :ok

    response_body = JSON.parse(response.body)
    assert_equal 'User retrieved successfully', response_body['message']

    user_data = response_body['user']
    assert_equal @user.id, user_data['id']
    assert_equal @user.uid, user_data['uid']
    assert_equal @user.email, user_data['email']
    assert_equal @user.first_name, user_data['first_name']
    assert_equal @user.last_name, user_data['last_name']
    assert_equal @user.full_name, user_data['full_name']
    assert_equal @user.phone, user_data['phone']
    assert_equal @user.description, user_data['description']
    assert_equal @user.date_of_birth.to_s, user_data['date_of_birth']
    assert_not_nil user_data['created_at']
    assert_not_nil user_data['updated_at']
  end

  test 'should get user by uid with authentication' do
    get api_v1_user_path(@user.uid), headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    assert_equal 'User retrieved successfully', response_body['message']

    user_data = response_body['user']
    assert_equal @user.id, user_data['id']
    assert_equal @user.uid, user_data['uid']
  end

  test 'should get other user by uid' do
    get api_v1_user_path(@other_user.uid)

    assert_response :ok

    response_body = JSON.parse(response.body)
    assert_equal 'User retrieved successfully', response_body['message']

    user_data = response_body['user']
    assert_equal @other_user.id, user_data['id']
    assert_equal @other_user.uid, user_data['uid']
    assert_equal @other_user.email, user_data['email']
    assert_equal @other_user.first_name, user_data['first_name']
    assert_equal @other_user.last_name, user_data['last_name']
  end

  test 'should return not found for non-existent user' do
    get api_v1_user_path('non-existent-uid')

    assert_response :not_found

    response_body = JSON.parse(response.body)
    assert_equal 'User not found', response_body['error']
  end

  test 'should reject unverified user retrieval' do
    unverified_user = User.create!(
      email: 'unverified@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Unverified',
      last_name: 'User'
    )

    get api_v1_user_path(unverified_user.uid)

    assert_response :forbidden

    response_body = JSON.parse(response.body)
    assert_equal 'User account is not verified', response_body['error']
  end

  # === UPDATE ACTION TESTS ===

  test 'should update own user profile' do
    put api_v1_user_path(@user.uid), 
        params: { 
          first_name: 'Updated John',
          last_name: 'Updated Doe',
          phone: '5555555555',
          description: 'Updated description',
          date_of_birth: '1991-02-20'
        }, 
        headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    assert_equal 'User profile updated successfully', response_body['message']

    user_data = response_body['user']
    assert_equal 'Updated John', user_data['first_name']
    assert_equal 'Updated Doe', user_data['last_name']
    assert_equal '5555555555', user_data['phone']
    assert_equal 'Updated description', user_data['description']
    assert_equal '1991-02-20', user_data['date_of_birth']
    assert_equal 'Updated John Updated Doe', user_data['full_name']

    # Verify user is actually updated in database
    @user.reload
    assert_equal 'Updated John', @user.first_name
    assert_equal 'Updated Doe', @user.last_name
    assert_equal '5555555555', @user.phone
    assert_equal 'Updated description', @user.description
    assert_equal Date.parse('1991-02-20'), @user.date_of_birth
  end

  test 'should update only provided fields' do
    original_description = @user.description
    original_phone = @user.phone

    put api_v1_user_path(@user.uid), 
        params: { first_name: 'Only First Name' }, 
        headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    user_data = response_body['user']
    assert_equal 'Only First Name', user_data['first_name']
    assert_equal @user.last_name, user_data['last_name']
    assert_equal original_phone, user_data['phone']
    assert_equal original_description, user_data['description']
  end

  test 'should not update other user profile' do
    put api_v1_user_path(@other_user.uid), 
        params: { first_name: 'Hacked Name' }, 
        headers: @headers

    assert_response :forbidden

    response_body = JSON.parse(response.body)
    assert_equal 'Access denied. You can only update your own profile.', response_body['error']

    # Verify other user is NOT updated
    @other_user.reload
    assert_equal 'Jane', @other_user.first_name
  end

  test 'should return not found for non-existent user' do
    put api_v1_user_path('non-existent-uid'), 
        params: { first_name: 'Test' }, 
        headers: @headers

    assert_response :not_found

    response_body = JSON.parse(response.body)
    assert_equal 'User not found', response_body['error']
  end

  test 'should reject update without authentication' do
    put api_v1_user_path(@user.uid), 
        params: { first_name: 'Test' }

    assert_response :unauthorized

    response_body = JSON.parse(response.body)
    assert_equal 'Authorization token required', response_body['error']
  end

  test 'should validate field lengths' do
    put api_v1_user_path(@user.uid), 
        params: { 
          first_name: 'a' * 101,  # Too long
          description: 'b' * 1001  # Too long
        }, 
        headers: @headers

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert_includes response_body['error'], 'First name cannot be longer than 100 characters'
  end

  test 'should validate date format' do
    put api_v1_user_path(@user.uid), 
        params: { date_of_birth: 'invalid-date' }, 
        headers: @headers

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert_equal 'Date of birth must be a valid date', response_body['error']
  end

  test 'should reject empty update' do
    put api_v1_user_path(@user.uid), 
        params: {}, 
        headers: @headers

    assert_response :bad_request

    response_body = JSON.parse(response.body)
    assert_equal 'No valid parameters provided for update', response_body['error']
  end

  test 'should ignore non-allowed fields' do
    original_email = @user.email

    put api_v1_user_path(@user.uid), 
        params: { 
          first_name: 'Updated Name',
          email: 'hacked@example.com',  # Should be ignored
          password: 'hacked_password'   # Should be ignored
        }, 
        headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    user_data = response_body['user']
    assert_equal 'Updated Name', user_data['first_name']
    assert_equal original_email, user_data['email']  # Should remain unchanged

    # Verify in database
    @user.reload
    assert_equal 'Updated Name', @user.first_name
    assert_equal original_email, @user.email
  end

  private

  def api_v1_user_path(uid)
    "/api/v1/users/#{uid}"
  end
end
