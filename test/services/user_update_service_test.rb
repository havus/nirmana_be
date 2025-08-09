require 'test_helper'

class UserUpdateServiceTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'John',
      last_name: 'Doe',
      phone: '1234567890',
      description: 'Original description',
      date_of_birth: '1990-01-15'
    )

    @other_user = User.create!(
      email: 'other@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Jane',
      last_name: 'Smith'
    )
  end

  test 'should update user profile successfully' do
    params = {
      first_name: 'Updated John',
      last_name: 'Updated Doe',
      phone: '5555555555',
      description: 'Updated description',
      date_of_birth: '1991-02-20'
    }

    result = UserUpdateService.new(@user.uid, @user, params).call

    assert result.success?
    assert_equal 'User profile updated successfully', result.message
    assert_not_nil result.data

    # Verify user is updated in database
    @user.reload
    assert_equal 'Updated John', @user.first_name
    assert_equal 'Updated Doe', @user.last_name
    assert_equal '5555555555', @user.phone
    assert_equal 'Updated description', @user.description
    assert_equal Date.parse('1991-02-20'), @user.date_of_birth
  end

  test 'should update only provided fields' do
    original_last_name = @user.last_name
    original_phone = @user.phone

    params = { first_name: 'Only First Name' }

    result = UserUpdateService.new(@user.uid, @user, params).call

    assert result.success?

    @user.reload
    assert_equal 'Only First Name', @user.first_name
    assert_equal original_last_name, @user.last_name
    assert_equal original_phone, @user.phone
  end

  test 'should not update other user profile' do
    params = { first_name: 'Hacked Name' }

    result = UserUpdateService.new(@other_user.uid, @user, params).call

    assert_not result.success?
    assert_equal 'Access denied. You can only update your own profile.', result.message
    assert_equal :forbidden, result.status

    # Verify other user is NOT updated
    @other_user.reload
    assert_equal 'Jane', @other_user.first_name
  end

  test 'should fail with non-existent user' do
    params = { first_name: 'Test' }

    result = UserUpdateService.new('non-existent-uid', @user, params).call

    assert_not result.success?
    assert_equal 'User not found', result.message
    assert_equal :not_found, result.status
  end

  test 'should fail without user authentication' do
    params = { first_name: 'Test' }

    result = UserUpdateService.new(@user.uid, nil, params).call

    assert_not result.success?
    assert_equal 'User authentication is required', result.message
    assert_equal :unauthorized, result.status
  end

  test 'should fail with blank user UID' do
    params = { first_name: 'Test' }

    result = UserUpdateService.new('', @user, params).call

    assert_not result.success?
    assert_equal 'User UID is required', result.message
    assert_equal :bad_request, result.status
  end

  test 'should fail with nil user UID' do
    params = { first_name: 'Test' }

    result = UserUpdateService.new(nil, @user, params).call

    assert_not result.success?
    assert_equal 'User UID is required', result.message
    assert_equal :bad_request, result.status
  end

  test 'should fail with empty params' do
    result = UserUpdateService.new(@user.uid, @user, {}).call

    assert_not result.success?
    assert_equal 'No valid parameters provided for update', result.message
    assert_equal :bad_request, result.status
  end

  test 'should fail with nil params' do
    result = UserUpdateService.new(@user.uid, @user, nil).call

    assert_not result.success?
    assert_equal 'No valid parameters provided for update', result.message
    assert_equal :bad_request, result.status
  end

  test 'should ignore non-allowed fields' do
    original_email = @user.email

    params = {
      first_name: 'Updated Name',
      email: 'hacked@example.com',    # Should be ignored
      password: 'hacked_password',    # Should be ignored
      admin: true                     # Should be ignored
    }

    result = UserUpdateService.new(@user.uid, @user, params).call

    assert result.success?

    @user.reload
    assert_equal 'Updated Name', @user.first_name
    assert_equal original_email, @user.email
  end

  test 'should validate first_name length' do
    params = { first_name: 'a' * 101 }  # Too long

    result = UserUpdateService.new(@user.uid, @user, params).call

    assert_not result.success?
    assert_includes result.message, 'First name cannot be longer than 100 characters'
    assert_equal :unprocessable_entity, result.status
  end

  test 'should validate last_name length' do
    params = { last_name: 'b' * 101 }  # Too long

    result = UserUpdateService.new(@user.uid, @user, params).call

    assert_not result.success?
    assert_includes result.message, 'Last name cannot be longer than 100 characters'
    assert_equal :unprocessable_entity, result.status
  end

  test 'should validate phone length' do
    params = { phone: '1' * 21 }  # Too long

    result = UserUpdateService.new(@user.uid, @user, params).call

    assert_not result.success?
    assert_includes result.message, 'Phone cannot be longer than 20 characters'
    assert_equal :unprocessable_entity, result.status
  end

  test 'should validate description length' do
    params = { description: 'x' * 1001 }  # Too long

    result = UserUpdateService.new(@user.uid, @user, params).call

    assert_not result.success?
    assert_includes result.message, 'Description cannot be longer than 1000 characters'
    assert_equal :unprocessable_entity, result.status
  end

  test 'should validate date_of_birth format' do
    params = { date_of_birth: 'invalid-date' }

    result = UserUpdateService.new(@user.uid, @user, params).call

    assert_not result.success?
    assert_equal 'Date of birth must be a valid date', result.message
    assert_equal :unprocessable_entity, result.status
  end

  test 'should accept valid date_of_birth formats' do
    valid_dates = ['1990-01-15', '2000-12-31', '1985-06-20']

    valid_dates.each do |date|
      params = { date_of_birth: date }

      result = UserUpdateService.new(@user.uid, @user, params).call

      assert result.success?, "Failed for date: #{date}"

      @user.reload
      assert_equal Date.parse(date), @user.date_of_birth
    end
  end

  test 'should filter empty string values' do
    params = {
      first_name: 'Updated Name',
      last_name: '',           # Empty string should be ignored
      phone: '   ',           # Whitespace should be ignored
      description: 'Valid description'
    }

    result = UserUpdateService.new(@user.uid, @user, params).call

    assert result.success?

    @user.reload
    assert_equal 'Updated Name', @user.first_name
    assert_equal 'Doe', @user.last_name  # Should remain unchanged
    assert_equal '1234567890', @user.phone  # Should remain unchanged
    assert_equal 'Valid description', @user.description
  end

  test 'should handle database validation errors' do
    # Force a validation error by making the description too long in the model
    User.any_instance.stubs(:valid?).returns(false)
    User.any_instance.stubs(:errors).returns(double(full_messages: ['Description is invalid']))

    params = { first_name: 'Test' }

    result = UserUpdateService.new(@user.uid, @user, params).call

    assert_not result.success?
    assert_includes result.message, 'Validation failed'
    assert_equal :unprocessable_entity, result.status
  end

  test 'should handle multiple validation errors' do
    params = {
      first_name: 'a' * 101,      # Too long
      description: 'x' * 1001,   # Too long
      date_of_birth: 'invalid'   # Invalid format
    }

    result = UserUpdateService.new(@user.uid, @user, params).call

    assert_not result.success?
    # Should return the first validation error
    assert_includes result.message, 'First name cannot be longer than 100 characters'
    assert_equal :unprocessable_entity, result.status
  end
end
