require 'test_helper'

class ProjectCreationServiceTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'John',
      last_name: 'Doe'
    )

    @valid_params = {
      name: 'Test Project',
      version: '1.0.0',
      board_config: {
        'dotsCountHorizontal' => 20,
        'dotsCountVertical' => 20,
        'marginBetweenNails' => 10,
        'paddingBoard' => 40,
        'boardColor' => '#8B4513'
      },
      nails: {
        '10,20' => { 'id' => 1, 'type' => 'standard' },
        '30,40' => { 'id' => 2, 'type' => 'corner' }
      }
    }
  end

  test 'successfully creates project with valid data' do
    result = ProjectCreationService.call(
      user: @user,
      params: @valid_params
    )

    assert result.success?
    assert_not_nil result.project
    assert_equal 'Test Project', result.project.name
    assert_equal '1.0.0', result.project.version
    assert_equal @user.id, result.project.user_id
    assert_not_nil result.project.board_config
    assert_not_nil result.project.nails
  end

  test 'sets default version when not provided' do
    params = @valid_params.except(:version)
    
    result = ProjectCreationService.call(
      user: @user,
      params: params
    )

    assert result.success?
    assert_equal '1.0.0', result.project.version
  end

  test 'fails when user is not provided' do
    result = ProjectCreationService.call(
      user: nil,
      params: @valid_params
    )

    assert_not result.success?
    assert_includes result.errors, 'User is required'
  end

  test 'fails when name is blank' do
    params = @valid_params.merge(name: '')
    
    result = ProjectCreationService.call(
      user: @user,
      params: params
    )

    assert_not result.success?
    assert_includes result.errors, 'Project name is required'
  end

  test 'fails when board_config is missing' do
    params = @valid_params.except(:board_config)
    
    result = ProjectCreationService.call(
      user: @user,
      params: params
    )

    assert_not result.success?
    assert_includes result.errors, 'Board config is required'
  end

  test 'fails when nails data is missing' do
    params = @valid_params.except(:nails)
    
    result = ProjectCreationService.call(
      user: @user,
      params: params
    )

    assert_not result.success?
    assert_includes result.errors, 'Nails data is required'
  end

  test 'fails when board_config lacks dotsCountHorizontal' do
    params = @valid_params.dup
    params[:board_config] = { 
      'dotsCountVertical' => 20,
      'marginBetweenNails' => 10,
      'paddingBoard' => 40,
      'boardColor' => '#8B4513'
    }
    
    result = ProjectCreationService.call(
      user: @user,
      params: params
    )

    assert_not result.success?
    assert_includes result.errors, 'Board config must include dotsCountHorizontal'
  end

  test 'fails when board_config lacks boardColor' do
    params = @valid_params.dup
    params[:board_config] = { 
      'dotsCountHorizontal' => 20,
      'dotsCountVertical' => 20,
      'marginBetweenNails' => 10,
      'paddingBoard' => 40
    }
    
    result = ProjectCreationService.call(
      user: @user,
      params: params
    )

    assert_not result.success?
    assert_includes result.errors, 'Board config must include boardColor'
  end

  test 'fails when nail position format is invalid' do
    params = @valid_params.dup
    params[:nails] = { 'invalid_position' => { 'id' => 1 } }
    
    result = ProjectCreationService.call(
      user: @user,
      params: params
    )

    assert_not result.success?
    assert_includes result.errors, "Invalid nail position format: invalid_position. Expected format: 'x,y'"
  end
end
