require 'test_helper'

class ProjectUpdateServiceTest < ActiveSupport::TestCase
  def setup
    @owner = User.create!(
      email: 'owner@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Project',
      last_name: 'Owner'
    )

    @other_user = User.create!(
      email: 'other@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Other',
      last_name: 'User'
    )

    @project = @owner.projects.create!(
      name: 'Original Project',
      version: '1.0.0',
      visibility: :personal,
      board_config: {
        'dimensions' => { 'width' => 800, 'height' => 600 },
        'appearance' => { 'color' => 'brown' }
      },
      nails: { '10,20' => { 'id' => 1, 'type' => 'standard' } }
    )
  end

  test 'successfully updates project name' do
    result = ProjectUpdateService.call(
      project_id: @project.id,
      current_user: @owner,
      params: { name: 'Updated Project Name' }
    )

    assert result.success?
    assert_equal 'Updated Project Name', result.project[:name]
    
    @project.reload
    assert_equal 'Updated Project Name', @project.name
    # Other fields should remain unchanged
    assert_equal '1.0.0', @project.version
    assert_equal 'personal', @project.visibility
  end

  test 'successfully updates version' do
    result = ProjectUpdateService.call(
      project_id: @project.id,
      current_user: @owner,
      params: { version: '2.0.0' }
    )

    assert result.success?
    assert_equal '2.0.0', result.project[:version]
    
    @project.reload
    assert_equal '2.0.0', @project.version
    # Other fields should remain unchanged
    assert_equal 'Original Project', @project.name
  end

  test 'successfully updates visibility from private to public' do
    result = ProjectUpdateService.call(
      project_id: @project.id,
      current_user: @owner,
      params: { visibility: 'shared' }
    )

    assert result.success?
    assert_equal 'shared', result.project[:visibility]
    
    @project.reload
    assert_equal 'shared', @project.visibility
  end

  test 'successfully updates visibility from public to private' do
    @project.update!(visibility: :shared)
    
    result = ProjectUpdateService.call(
      project_id: @project.id,
      current_user: @owner,
      params: { visibility: 'personal' }
    )

    assert result.success?
    assert_equal 'personal', result.project[:visibility]
    
    @project.reload
    assert_equal 'personal', @project.visibility
  end

  test 'successfully updates board_config' do
    new_board_config = {
      'dimensions' => { 'width' => 1000, 'height' => 800 },
      'appearance' => { 'color' => 'oak', 'texture' => 'smooth' }
    }

    result = ProjectUpdateService.call(
      project_id: @project.id,
      current_user: @owner,
      params: { board_config: new_board_config }
    )

    assert result.success?
    assert_equal new_board_config, result.project[:board_config]
    
    @project.reload
    assert_equal 1000, @project.board_config['dimensions']['width']
    assert_equal 'oak', @project.board_config['appearance']['color']
  end

  test 'successfully updates nails' do
    new_nails = {
      '30,40' => { 'id' => 2, 'type' => 'corner' },
      '50,60' => { 'id' => 3, 'type' => 'edge' }
    }

    result = ProjectUpdateService.call(
      project_id: @project.id,
      current_user: @owner,
      params: { nails: new_nails }
    )

    assert result.success?
    assert_equal new_nails, result.project[:nails]
    
    @project.reload
    assert_equal new_nails, @project.nails
  end

  test 'successfully updates multiple fields at once' do
    result = ProjectUpdateService.call(
      project_id: @project.id,
      current_user: @owner,
      params: {
        name: 'Multi-Update Project',
        version: '3.0.0',
        visibility: 'shared'
      }
    )

    assert result.success?
    assert_equal 'Multi-Update Project', result.project[:name]
    assert_equal '3.0.0', result.project[:version]
    assert_equal 'shared', result.project[:visibility]
    
    @project.reload
    assert_equal 'Multi-Update Project', @project.name
    assert_equal '3.0.0', @project.version
    assert_equal 'shared', @project.visibility
  end

  test 'fails when other user tries to update project' do
    result = ProjectUpdateService.call(
      project_id: @project.id,
      current_user: @other_user,
      params: { name: 'Hacked Name' }
    )

    assert_not result.success?
    assert_includes result.errors, 'Access denied. You can only update your own projects.'
    
    @project.reload
    assert_equal 'Original Project', @project.name # Should remain unchanged
  end

  test 'fails when project does not exist' do
    result = ProjectUpdateService.call(
      project_id: 99999,
      current_user: @owner,
      params: { name: 'Non-existent Project' }
    )

    assert_not result.success?
    assert_includes result.errors, 'Project not found'
  end

  test 'fails when project_id is blank' do
    result = ProjectUpdateService.call(
      project_id: nil,
      current_user: @owner,
      params: { name: 'Test' }
    )

    assert_not result.success?
    assert_includes result.errors, 'Project ID is required'
  end

  test 'fails when current_user is not provided' do
    result = ProjectUpdateService.call(
      project_id: @project.id,
      current_user: nil,
      params: { name: 'Test' }
    )

    assert_not result.success?
    assert_includes result.errors, 'User authentication is required'
  end

  test 'fails with blank name' do
    result = ProjectUpdateService.call(
      project_id: @project.id,
      current_user: @owner,
      params: { name: '' }
    )

    assert_not result.success?
    assert_includes result.errors, 'Project name cannot be blank'
  end

  test 'fails with invalid visibility' do
    result = ProjectUpdateService.call(
      project_id: @project.id,
      current_user: @owner,
      params: { visibility: 'invalid' }
    )

    assert_not result.success?
    assert_includes result.errors, 'Visibility must be either "private" or "public"'
  end

  test 'fails with invalid nail position format' do
    result = ProjectUpdateService.call(
      project_id: @project.id,
      current_user: @owner,
      params: { nails: { 'invalid_position' => { 'id' => 1 } } }
    )

    assert_not result.success?
    assert_includes result.errors, "Invalid nail position format: invalid_position. Expected format: 'x,y'"
  end

  test 'includes owner information in response' do
    result = ProjectUpdateService.call(
      project_id: @project.id,
      current_user: @owner,
      params: { name: 'Updated Project' }
    )

    assert result.success?
    owner = result.project[:owner]
    assert_equal @owner.id, owner[:id]
    assert_equal @owner.uid, owner[:uid]
    assert_equal @owner.first_name, owner[:first_name]
    assert_equal @owner.last_name, owner[:last_name]
    assert_equal @owner.full_name, owner[:full_name]
  end

  test 'does not update fields that are not provided' do
    original_name = @project.name
    original_version = @project.version
    
    result = ProjectUpdateService.call(
      project_id: @project.id,
      current_user: @owner,
      params: { visibility: 'shared' } # Only updating visibility
    )

    assert result.success?
    
    @project.reload
    # These should remain unchanged
    assert_equal original_name, @project.name
    assert_equal original_version, @project.version
    # This should be updated
    assert_equal 'shared', @project.visibility
  end
end
