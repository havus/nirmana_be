require 'test_helper'

class ProjectListingServiceTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'John',
      last_name: 'Doe'
    )

    # Create test projects
    5.times do |i|
      @user.projects.create!(
        name: "Project #{i + 1}",
        version: '1.0.0',
        board_config: { 
          'dimensions' => { 'width' => 800, 'height' => 600 },
          'appearance' => { 'color' => 'brown' }
        },
        nails: { "#{i},#{i}" => { 'id' => i + 1, 'type' => 'standard' } }
      )
    end
  end

  test 'successfully returns projects with default pagination' do
    result = ProjectListingService.call(user: @user)

    assert result.success?
    assert_equal 5, result.projects.length
    assert_equal 1, result.pagination[:page_number]
    assert_equal 20, result.pagination[:page_size]
    assert_equal 5, result.pagination[:total_count]
    assert_equal 1, result.pagination[:total_pages]
    assert_equal false, result.pagination[:has_next_page]
    assert_equal false, result.pagination[:has_previous_page]

    # Check projects are ordered by created_at desc (newest first)
    names = result.projects.map { |p| p[:name] }
    assert_equal ['Project 5', 'Project 4', 'Project 3', 'Project 2', 'Project 1'], names
  end

  test 'successfully returns projects with custom pagination' do
    result = ProjectListingService.call(
      user: @user,
      page_number: 2,
      page_size: 2
    )

    assert result.success?
    assert_equal 2, result.projects.length
    assert_equal 2, result.pagination[:page_number]
    assert_equal 2, result.pagination[:page_size]
    assert_equal 5, result.pagination[:total_count]
    assert_equal 3, result.pagination[:total_pages]
    assert_equal true, result.pagination[:has_next_page]
    assert_equal true, result.pagination[:has_previous_page]
  end

  test 'returns empty array when user has no projects' do
    empty_user = User.create!(
      email: 'empty@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Empty',
      last_name: 'User'
    )

    result = ProjectListingService.call(user: empty_user)

    assert result.success?
    assert_equal [], result.projects
    assert_equal 0, result.pagination[:total_count]
    assert_equal 0, result.pagination[:total_pages]
    assert_equal false, result.pagination[:has_next_page]
    assert_equal false, result.pagination[:has_previous_page]
  end

  test 'normalizes invalid page_number to 1' do
    result = ProjectListingService.call(
      user: @user,
      page_number: -5,
      page_size: 10
    )

    assert result.success?
    assert_equal 1, result.pagination[:page_number]
  end

  test 'normalizes page_number from string' do
    result = ProjectListingService.call(
      user: @user,
      page_number: '2',
      page_size: '3'
    )

    assert result.success?
    assert_equal 2, result.pagination[:page_number]
    assert_equal 3, result.pagination[:page_size]
  end

  test 'limits page_size to maximum 100' do
    result = ProjectListingService.call(
      user: @user,
      page_number: 1,
      page_size: 1000
    )

    assert result.success?
    assert_equal 100, result.pagination[:page_size]
  end

  test 'normalizes invalid page_size to 1' do
    result = ProjectListingService.call(
      user: @user,
      page_number: 1,
      page_size: -10
    )

    assert result.success?
    assert_equal 1, result.pagination[:page_size]
  end

  test 'fails when user is not provided' do
    result = ProjectListingService.call(user: nil)

    assert_not result.success?
    assert_includes result.errors, 'User is required'
  end

  test 'includes all required project fields in response' do
    result = ProjectListingService.call(user: @user)

    assert result.success?
    project = result.projects.first
    
    assert_not_nil project[:id]
    assert_equal @user.id, project[:user_id]
    assert_not_nil project[:name]
    assert_not_nil project[:version]
    assert_not_nil project[:board_config]
    assert_not_nil project[:nails]
    assert_not_nil project[:created_at]
    assert_not_nil project[:updated_at]
  end

  test 'handles pagination beyond available pages gracefully' do
    result = ProjectListingService.call(
      user: @user,
      page_number: 10,
      page_size: 10
    )

    assert result.success?
    assert_equal [], result.projects
    assert_equal 10, result.pagination[:page_number]
    assert_equal 5, result.pagination[:total_count]
    assert_equal false, result.pagination[:has_next_page]
    assert_equal true, result.pagination[:has_previous_page]
  end
end
