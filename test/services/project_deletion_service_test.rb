require 'test_helper'

class ProjectDeletionServiceTest < ActiveSupport::TestCase
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
      name: 'Test Project',
      version: '1.0.0',
      visibility: :personal,
      board_config: {
        'dimensions' => { 'width' => 800, 'height' => 600 },
        'appearance' => { 'color' => 'brown' }
      },
      nails: { '10,20' => { 'id' => 1, 'type' => 'standard' } }
    )
  end

  test 'successfully deletes own project' do
    project_id = @project.id
    name = @project.name

    result = ProjectDeletionService.call(
      project_id: project_id,
      current_user: @owner
    )

    assert result.success?
    assert_equal project_id, result.project[:id]
    assert_equal name, result.project[:name]
    assert_equal @owner.id, result.project[:user_id]
    assert_not_nil result.project[:owner]
    assert_equal @owner.full_name, result.project[:owner][:full_name]

    # Verify project is actually deleted from database
    assert_nil Project.find_by(id: project_id)
  end

  test 'includes all required project fields in response before deletion' do
    result = ProjectDeletionService.call(
      project_id: @project.id,
      current_user: @owner
    )

    assert result.success?
    project = result.project

    assert_not_nil project[:id]
    assert_not_nil project[:user_id]
    assert_not_nil project[:name]
    assert_not_nil project[:version]
    assert_not_nil project[:visibility]
    assert_not_nil project[:created_at]
    assert_not_nil project[:updated_at]
    assert_not_nil project[:owner]
    
    # Check owner details
    owner = project[:owner]
    assert_not_nil owner[:id]
    assert_not_nil owner[:uid]
    assert_not_nil owner[:first_name]
    assert_not_nil owner[:last_name]
    assert_not_nil owner[:full_name]
  end

  test 'fails when other user tries to delete project' do
    project_id = @project.id

    result = ProjectDeletionService.call(
      project_id: project_id,
      current_user: @other_user
    )

    assert_not result.success?
    assert_includes result.errors, 'Access denied. You can only delete your own projects.'

    # Verify project is NOT deleted from database
    assert_not_nil Project.find_by(id: project_id)
  end

  test 'fails when project does not exist' do
    result = ProjectDeletionService.call(
      project_id: 99999,
      current_user: @owner
    )

    assert_not result.success?
    assert_includes result.errors, 'Project not found'
  end

  test 'fails when project_id is blank' do
    result = ProjectDeletionService.call(
      project_id: nil,
      current_user: @owner
    )

    assert_not result.success?
    assert_includes result.errors, 'Project ID is required'
  end

  test 'fails when project_id is empty string' do
    result = ProjectDeletionService.call(
      project_id: '',
      current_user: @owner
    )

    assert_not result.success?
    assert_includes result.errors, 'Project ID is required'
  end

  test 'fails when current_user is not provided' do
    result = ProjectDeletionService.call(
      project_id: @project.id,
      current_user: nil
    )

    assert_not result.success?
    assert_includes result.errors, 'User authentication is required'
  end

  test 'handles string project_id correctly' do
    project_id = @project.id
    
    result = ProjectDeletionService.call(
      project_id: project_id.to_s,
      current_user: @owner
    )

    assert result.success?
    assert_equal project_id, result.project[:id]

    # Verify project is actually deleted from database
    assert_nil Project.find_by(id: project_id)
  end

  test 'deletes public project owned by user' do
    public_project = @owner.projects.create!(
      name: 'Public Project',
      version: '1.0.0',
      visibility: :shared,
      board_config: { 'dimensions' => {}, 'appearance' => {} },
      nails: { '0,0' => { 'id' => 1 } }
    )

    project_id = public_project.id

    result = ProjectDeletionService.call(
      project_id: project_id,
      current_user: @owner
    )

    assert result.success?
    assert_equal 'Public Project', result.project[:name]
    assert_equal 'shared', result.project[:visibility]

    # Verify project is actually deleted from database
    assert_nil Project.find_by(id: project_id)
  end

  test 'cannot delete other user public project' do
    public_project = @other_user.projects.create!(
      name: 'Other User Public Project',
      version: '1.0.0',
      visibility: :shared,
      board_config: { 'dimensions' => {}, 'appearance' => {} },
      nails: { '0,0' => { 'id' => 1 } }
    )

    project_id = public_project.id

    result = ProjectDeletionService.call(
      project_id: project_id,
      current_user: @owner
    )

    assert_not result.success?
    assert_includes result.errors, 'Access denied. You can only delete your own projects.'

    # Verify project is NOT deleted from database
    assert_not_nil Project.find_by(id: project_id)
  end

  test 'deletes project and its associations' do
    # This test ensures that when a project is deleted, 
    # any associated records are handled properly (if any exist in the future)
    project_id = @project.id

    result = ProjectDeletionService.call(
      project_id: project_id,
      current_user: @owner
    )

    assert result.success?

    # Verify project is completely removed
    assert_nil Project.find_by(id: project_id)
  end
end
