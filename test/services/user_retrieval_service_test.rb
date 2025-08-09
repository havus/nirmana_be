require 'test_helper'

class UserRetrievalServiceTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'John',
      last_name: 'Doe',
      phone: '1234567890',
      description: 'Test description',
      date_of_birth: '1990-01-15'
    )
    @user.verify_email!

    @other_user = User.create!(
      email: 'other@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Jane',
      last_name: 'Smith',
      phone: '0987654321'
    )
    @other_user.verify_email!

    @unverified_user = User.create!(
      email: 'unverified@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Unverified',
      last_name: 'User'
    )
  end

  test 'should retrieve user successfully' do
    result = UserRetrievalService.new(@user.uid).call

    assert result.success?
    assert_equal 'User retrieved successfully', result.message
    assert_not_nil result.data
    assert_equal @user.id, result.data.id
  end

  test 'should retrieve other verified user successfully' do
    result = UserRetrievalService.new(@other_user.uid).call

    assert result.success?
    assert_equal 'User retrieved successfully', result.message
    assert_not_nil result.data
    assert_equal @other_user.id, result.data.id
  end

  test 'should fail with non-existent user' do
    result = UserRetrievalService.new('non-existent-uid').call

    assert_not result.success?
    assert_equal 'User not found', result.message
    assert_equal :not_found, result.status
  end

  test 'should fail with blank user UID' do
    result = UserRetrievalService.new('').call

    assert_not result.success?
    assert_equal 'User UID is required', result.message
    assert_equal :bad_request, result.status
  end

  test 'should fail with nil user UID' do
    result = UserRetrievalService.new(nil).call

    assert_not result.success?
    assert_equal 'User UID is required', result.message
    assert_equal :bad_request, result.status
  end

  test 'should fail for unverified user' do
    result = UserRetrievalService.new(@unverified_user.uid).call

    assert_not result.success?
    assert_equal 'User account is not verified', result.message
    assert_equal :forbidden, result.status
  end

  test 'should return user object with all fields' do
    @user.update!(
      description: 'Updated description',
      date_of_birth: '1990-01-15',
      avatar_url: 'https://example.com/avatar.jpg'
    )

    result = UserRetrievalService.new(@user.uid).call

    assert result.success?

    user_data = result.data
    assert_equal @user.id, user_data.id
    assert_equal @user.uid, user_data.uid
    assert_equal @user.email, user_data.email
    assert_equal @user.first_name, user_data.first_name
    assert_equal @user.last_name, user_data.last_name
    assert_equal @user.phone, user_data.phone
    assert_equal @user.description, user_data.description
    assert_equal @user.date_of_birth, user_data.date_of_birth
    assert_equal @user.avatar_url, user_data.avatar_url
    assert_equal @user.status, user_data.status
    assert_equal @user.email_verified_at, user_data.email_verified_at
  end

  test 'should handle database errors gracefully' do
    # Simulate a database error
    User.stubs(:find_by).raises(StandardError.new('Database error'))

    result = UserRetrievalService.new(@user.uid).call

    assert_not result.success?
    assert_equal 'Failed to retrieve user. Please try again.', result.message
    assert_equal :internal_server_error, result.status
  end
end
