require 'test_helper'

class UserListingServiceTest < ActiveSupport::TestCase
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

  test 'should list verified users successfully' do
    result = UserListingService.new(@user).call

    assert result.success?
    assert_equal 'Users retrieved successfully', result.message
    assert_not_nil result.data

    users = result.data[:users]
    pagination = result.data[:pagination]

    # Should only include verified users
    assert_equal 2, users.length
    assert_equal 2, pagination[:total_count]

    # Check users are ordered by first_name, last_name
    user_names = users.map { |u| u[:first_name] }
    assert_equal ['Jane', 'John'], user_names

    # Check user data structure
    user_data = users.first
    assert_not_nil user_data[:id]
    assert_not_nil user_data[:uid]
    assert_not_nil user_data[:email]
    assert_not_nil user_data[:first_name]
    assert_not_nil user_data[:last_name]
    assert_not_nil user_data[:full_name]
    assert_not_nil user_data[:created_at]
    assert_not_nil user_data[:updated_at]
  end

  test 'should handle pagination correctly' do
    result = UserListingService.new(@user, 1, 1).call

    assert result.success?

    users = result.data[:users]
    pagination = result.data[:pagination]

    assert_equal 1, users.length
    assert_equal 1, pagination[:page_number]
    assert_equal 1, pagination[:page_size]
    assert_equal 2, pagination[:total_count]
    assert_equal 2, pagination[:total_pages]
    assert_equal true, pagination[:has_next_page]
    assert_equal false, pagination[:has_previous_page]
  end

  test 'should handle second page correctly' do
    result = UserListingService.new(@user, 2, 1).call

    assert result.success?

    users = result.data[:users]
    pagination = result.data[:pagination]

    assert_equal 1, users.length
    assert_equal 2, pagination[:page_number]
    assert_equal 1, pagination[:page_size]
    assert_equal 2, pagination[:total_count]
    assert_equal 2, pagination[:total_pages]
    assert_equal false, pagination[:has_next_page]
    assert_equal true, pagination[:has_previous_page]
  end

  test 'should use default pagination values' do
    result = UserListingService.new(@user).call

    assert result.success?

    pagination = result.data[:pagination]
    assert_equal 1, pagination[:page_number]
    assert_equal 20, pagination[:page_size]
  end

  test 'should normalize invalid page numbers' do
    # Test negative page number
    result = UserListingService.new(@user, -1, 10).call
    assert result.success?
    assert_equal 1, result.data[:pagination][:page_number]

    # Test zero page number
    result = UserListingService.new(@user, 0, 10).call
    assert result.success?
    assert_equal 1, result.data[:pagination][:page_number]

    # Test non-numeric page number
    result = UserListingService.new(@user, 'invalid', 10).call
    assert result.success?
    assert_equal 1, result.data[:pagination][:page_number]
  end

  test 'should normalize invalid page sizes' do
    # Test negative page size
    result = UserListingService.new(@user, 1, -10).call
    assert result.success?
    assert_equal 20, result.data[:pagination][:page_size]

    # Test zero page size
    result = UserListingService.new(@user, 1, 0).call
    assert result.success?
    assert_equal 20, result.data[:pagination][:page_size]

    # Test page size exceeding maximum
    result = UserListingService.new(@user, 1, 200).call
    assert result.success?
    assert_equal 100, result.data[:pagination][:page_size]
  end

  test 'should fail without user authentication' do
    result = UserListingService.new(nil).call

    assert_not result.success?
    assert_equal 'User authentication is required', result.message
    assert_equal :unauthorized, result.status
  end

  test 'should exclude unverified users' do
    result = UserListingService.new(@user).call

    assert result.success?

    users = result.data[:users]
    user_emails = users.map { |u| u[:email] }

    assert_includes user_emails, @user.email
    assert_includes user_emails, @other_user.email
    assert_not_includes user_emails, @unverified_user.email
  end

  test 'should include all user fields' do
    @user.update!(
      description: 'Updated description',
      date_of_birth: '1990-01-15',
      avatar_url: 'https://example.com/avatar.jpg'
    )

    result = UserListingService.new(@user).call

    assert result.success?

    user_data = result.data[:users].find { |u| u[:id] == @user.id }
    assert_equal @user.description, user_data[:description]
    assert_equal @user.date_of_birth, user_data[:date_of_birth]
    assert_equal @user.avatar_url, user_data[:avatar_url]
    assert_equal @user.phone, user_data[:phone]
    assert_equal @user.status, user_data[:status]
    assert_equal @user.email_verified_at.iso8601, user_data[:email_verified_at].iso8601
  end

  test 'should handle empty result set' do
    # Make all users unverified
    User.update_all(email_verified_at: nil, status: 0)

    result = UserListingService.new(@user).call

    assert result.success?
    assert_equal 'Users retrieved successfully', result.message

    users = result.data[:users]
    pagination = result.data[:pagination]

    assert_equal 0, users.length
    assert_equal 0, pagination[:total_count]
    assert_equal 0, pagination[:total_pages]
    assert_equal false, pagination[:has_next_page]
    assert_equal false, pagination[:has_previous_page]
  end
end
