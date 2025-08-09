require 'test_helper'

class ProjectRetrievalServiceTest < ActiveSupport::TestCase
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

    @private_project = @owner.projects.create!(
      name: 'Private Project',
      version: '1.0.0',
      visibility: :personal,
      board_config: {
        'dimensions' => { 'width' => 800, 'height' => 600 },
        'appearance' => { 'color' => 'brown' }
      },
      nails: { '10,20' => { 'id' => 1, 'type' => 'standard' } }
    )

    @public_project = @owner.projects.create!(
      name: 'Public Project',
      version: '1.0.0',
      visibility: :shared,
      board_config: {
        'dimensions' => { 'width' => 800, 'height' => 600 },
        'appearance' => { 'color' => 'brown' }
      },
      nails: { '10,20' => { 'id' => 1, 'type' => 'standard' } }
    )
  end

  test 'owner can access their own private project' do
    result = ProjectRetrievalService.call(
      project_id: @private_project.id,
      current_user: @owner
    )

    assert result.success?
    assert_equal @private_project.id, result.project[:id]
    assert_equal 'Private Project', result.project[:name]
    assert_equal 'personal', result.project[:visibility]
    assert_not_nil result.project[:owner]
    assert_equal @owner.id, result.project[:owner][:id]
    assert_equal @owner.full_name, result.project[:owner][:full_name]
  end

  test 'owner can access their own public project' do
    result = ProjectRetrievalService.call(
      project_id: @public_project.id,
      current_user: @owner
    )

    assert result.success?
    assert_equal @public_project.id, result.project[:id]
    assert_equal 'Public Project', result.project[:name]
    assert_equal 'shared', result.project[:visibility]
  end

  test 'other user can access public project' do
    result = ProjectRetrievalService.call(
      project_id: @public_project.id,
      current_user: @other_user
    )

    assert result.success?
    assert_equal @public_project.id, result.project[:id]
    assert_equal 'Public Project', result.project[:name]
    assert_equal 'shared', result.project[:visibility]
    assert_equal @owner.id, result.project[:owner][:id]
  end

  test 'other user cannot access private project' do
    result = ProjectRetrievalService.call(
      project_id: @private_project.id,
      current_user: @other_user
    )

    assert_not result.success?
    assert_includes result.errors, 'Access denied'
  end

  test 'fails when project does not exist' do
    result = ProjectRetrievalService.call(
      project_id: 99999,
      current_user: @owner
    )

    assert_not result.success?
    assert_includes result.errors, 'Project not found'
  end

  test 'fails when project_id is blank' do
    result = ProjectRetrievalService.call(
      project_id: nil,
      current_user: @owner
    )

    assert_not result.success?
    assert_includes result.errors, 'Project ID is required'
  end

  test 'fails when current_user is not provided' do
    result = ProjectRetrievalService.call(
      project_id: @public_project.id,
      current_user: nil
    )

    assert_not result.success?
    assert_includes result.errors, 'User authentication is required'
  end

  test 'includes all required project fields in response' do
    result = ProjectRetrievalService.call(
      project_id: @private_project.id,
      current_user: @owner
    )

    assert result.success?
    project = result.project

    assert_not_nil project[:id]
    assert_not_nil project[:user_id]
    assert_not_nil project[:name]
    assert_not_nil project[:version]
    assert_not_nil project[:visibility]
    assert_not_nil project[:board_config]
    assert_not_nil project[:nails]
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

  test 'handles string project_id correctly' do
    result = ProjectRetrievalService.call(
      project_id: @public_project.id.to_s,
      current_user: @owner
    )

    assert result.success?
    assert_equal @public_project.id, result.project[:id]
  end
end
