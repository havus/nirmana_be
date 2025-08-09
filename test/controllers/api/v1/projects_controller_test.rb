require 'test_helper'

class Api::V1::ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'John',
      last_name: 'Doe'
    )

    @session = UserSession.create_for_user(@user)
    @headers = { 'Authorization' => "Bearer #{@session.session_token}" }

    @valid_project_params = {
      project: {
        name: 'MDF Grid Test Project',
        version: '1.0.0',
        board_config: {
          dimensions: { width: 800, height: 600 },
          appearance: { color: 'brown', texture: 'wood' }
        },
        nails: {
          '10,20' => { id: 1, type: 'standard' },
          '30,40' => { id: 2, type: 'corner' }
        }
      }
    }
  end

  test 'should get user projects with default pagination' do
    # Create some projects for the user
    3.times do |i|
      @user.projects.create!(
        name: "Project #{i + 1}",
        version: '1.0.0',
        board_config: { dimensions: {}, appearance: {} },
        nails: { "#{i},#{i}" => { id: i } }
      )
    end

    get api_v1_projects_path, headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    
    assert_equal 3, response_body['projects'].length
    assert_equal 1, response_body['pagination']['page_number']
    assert_equal 20, response_body['pagination']['page_size']
    assert_equal 3, response_body['pagination']['total_count']
    assert_equal 1, response_body['pagination']['total_pages']
    assert_equal false, response_body['pagination']['has_next_page']
    assert_equal false, response_body['pagination']['has_previous_page']

    # Check projects are ordered by created_at desc (newest first)
    names = response_body['projects'].map { |p| p['name'] }
    assert_equal ['Project 3', 'Project 2', 'Project 1'], names
  end

  test 'should get user projects with custom pagination' do
    # Create 25 projects
    25.times do |i|
      @user.projects.create!(
        name: "Project #{i + 1}",
        version: '1.0.0',
        board_config: { dimensions: {}, appearance: {} },
        nails: { "#{i},#{i}" => { id: i } }
      )
    end

    get api_v1_projects_path, 
        params: { page_number: 2, page_size: 10 },
        headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    
    assert_equal 10, response_body['projects'].length
    assert_equal 2, response_body['pagination']['page_number']
    assert_equal 10, response_body['pagination']['page_size']
    assert_equal 25, response_body['pagination']['total_count']
    assert_equal 3, response_body['pagination']['total_pages']
    assert_equal true, response_body['pagination']['has_next_page']
    assert_equal true, response_body['pagination']['has_previous_page']
  end

  test 'should return empty array when user has no projects' do
    get api_v1_projects_path, headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    
    assert_equal [], response_body['projects']
    assert_equal 0, response_body['pagination']['total_count']
    assert_equal 0, response_body['pagination']['total_pages']
    assert_equal false, response_body['pagination']['has_next_page']
    assert_equal false, response_body['pagination']['has_previous_page']
  end

  test 'should only return current user projects' do
    # Create another user with projects
    other_user = User.create!(
      email: 'other@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Jane',
      last_name: 'Doe'
    )
    
    other_user.projects.create!(
      name: 'Other User Project',
      version: '1.0.0',
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    # Create project for current user
    @user.projects.create!(
      name: 'My Project',
      version: '1.0.0',
      board_config: { dimensions: {}, appearance: {} },
      nails: { '1,1' => { id: 1 } }
    )

    get api_v1_projects_path, headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    
    assert_equal 1, response_body['projects'].length
    assert_equal 'My Project', response_body['projects'][0]['name']
    assert_equal @user.id, response_body['projects'][0]['user_id']
  end

  test 'should reject request without authentication' do
    get api_v1_projects_path

    assert_response :unauthorized

    response_body = JSON.parse(response.body)
    assert_equal 'Authorization token required', response_body['error']
  end

  test 'should handle invalid page parameters gracefully' do
    @user.projects.create!(
      name: 'Test Project',
      version: '1.0.0',
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    # Test negative page number
    get api_v1_projects_path, 
        params: { page_number: -1, page_size: 5 },
        headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    assert_equal 1, response_body['pagination']['page_number'] # Should default to 1
    assert_equal 5, response_body['pagination']['page_size']
  end

  test 'should limit page size to maximum 100' do
    get api_v1_projects_path, 
        params: { page_size: 1000 },
        headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    assert_equal 100, response_body['pagination']['page_size'] # Should be capped at 100
  end

  # === SHOW ACTION TESTS ===

  test 'should get own private project' do
    project = @user.projects.create!(
      name: 'My Private Project',
      version: '1.0.0',
      visibility: :personal,
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    get api_v1_project_path(project), headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    project_data = response_body['project']
    
    assert_equal project.id, project_data['id']
    assert_equal 'My Private Project', project_data['name']
    assert_equal 'personal', project_data['visibility']
    assert_equal @user.id, project_data['user_id']
    assert_not_nil project_data['owner']
    assert_equal @user.id, project_data['owner']['id']
    assert_equal @user.full_name, project_data['owner']['full_name']
  end

  test 'should get own public project' do
    project = @user.projects.create!(
      name: 'My Public Project',
      version: '1.0.0',
      visibility: :shared,
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    get api_v1_project_path(project), headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    project_data = response_body['project']
    
    assert_equal project.id, project_data['id']
    assert_equal 'My Public Project', project_data['name']
    assert_equal 'shared', project_data['visibility']
  end

  test 'should get other user public project' do
    other_user = User.create!(
      email: 'other@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Other',
      last_name: 'User'
    )

    project = other_user.projects.create!(
      name: 'Other User Public Project',
      version: '1.0.0',
      visibility: :shared,
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    get api_v1_project_path(project), headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    project_data = response_body['project']
    
    assert_equal project.id, project_data['id']
    assert_equal 'Other User Public Project', project_data['name']
    assert_equal 'shared', project_data['visibility']
    assert_equal other_user.id, project_data['user_id']
    assert_equal other_user.full_name, project_data['owner']['full_name']
  end

  test 'should not get other user private project' do
    other_user = User.create!(
      email: 'other@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Other',
      last_name: 'User'
    )

    project = other_user.projects.create!(
      name: 'Other User Private Project',
      version: '1.0.0',
      visibility: :personal,
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    get api_v1_project_path(project), headers: @headers

    assert_response :forbidden

    response_body = JSON.parse(response.body)
    assert_equal 'Access denied', response_body['error']
  end

  test 'should return not found for non-existent project' do
    get api_v1_project_path(99999), headers: @headers

    assert_response :not_found

    response_body = JSON.parse(response.body)
    assert_equal 'Project not found', response_body['error']
  end

  test 'should reject show request without authentication' do
    project = @user.projects.create!(
      name: 'Test Project',
      version: '1.0.0',
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    get api_v1_project_path(project)

    assert_response :unauthorized

    response_body = JSON.parse(response.body)
    assert_equal 'Authorization token required', response_body['error']
  end

  # === UPDATE ACTION TESTS ===

  test 'should update own project name' do
    project = @user.projects.create!(
      name: 'Original Name',
      version: '1.0.0',
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    patch api_v1_project_path(project),
          params: { name: 'Updated Name' },
          headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    assert_equal 'Project updated successfully', response_body['message']
    assert_equal 'Updated Name', response_body['project']['name']
    
    project.reload
    assert_equal 'Updated Name', project.name
  end

  test 'should update project visibility' do
    project = @user.projects.create!(
      name: 'Test Project',
      version: '1.0.0',
      visibility: :personal,
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    patch api_v1_project_path(project),
          params: { visibility: 'shared' },
          headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    assert_equal 'shared', response_body['project']['visibility']
    
    project.reload
    assert_equal 'shared', project.visibility
  end

  test 'should update multiple fields at once' do
    project = @user.projects.create!(
      name: 'Original Project',
      version: '1.0.0',
      visibility: :personal,
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    patch api_v1_project_path(project),
          params: {
            name: 'Multi-Update Project',
            version: '2.0.0',
            visibility: 'shared'
          },
          headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    project_data = response_body['project']
    
    assert_equal 'Multi-Update Project', project_data['name']
    assert_equal '2.0.0', project_data['version']
    assert_equal 'shared', project_data['visibility']
    
    project.reload
    assert_equal 'Multi-Update Project', project.name
    assert_equal '2.0.0', project.version
    assert_equal 'shared', project.visibility
  end

  test 'should update board_config' do
    project = @user.projects.create!(
      name: 'Test Project',
      version: '1.0.0',
      board_config: { dimensions: { width: 800 }, appearance: { color: 'brown' } },
      nails: { '0,0' => { id: 1 } }
    )

    new_board_config = {
      dimensions: { width: 1000, height: 800 },
      appearance: { color: 'oak', texture: 'smooth' }
    }

    patch api_v1_project_path(project),
          params: { board_config: new_board_config },
          headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    assert_equal new_board_config.stringify_keys, response_body['project']['board_config']
    
    project.reload
    assert_equal 1000, project.board_config['dimensions']['width']
    assert_equal 'oak', project.board_config['appearance']['color']
  end

  test 'should not update other user project' do
    other_user = User.create!(
      email: 'other@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Other',
      last_name: 'User'
    )

    project = other_user.projects.create!(
      name: 'Other User Project',
      version: '1.0.0',
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    patch api_v1_project_path(project),
          params: { name: 'Hacked Name' },
          headers: @headers

    assert_response :forbidden

    response_body = JSON.parse(response.body)
    assert_equal 'Access denied. You can only update your own projects.', response_body['error']
    
    project.reload
    assert_equal 'Other User Project', project.name # Should remain unchanged
  end

  test 'should return not found for non-existent project update' do
    patch api_v1_project_path(99999),
          params: { name: 'Test' },
          headers: @headers

    assert_response :not_found

    response_body = JSON.parse(response.body)
    assert_equal 'Project not found', response_body['error']
  end

  test 'should reject update without authentication' do
    project = @user.projects.create!(
      name: 'Test Project',
      version: '1.0.0',
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    patch api_v1_project_path(project),
          params: { name: 'Updated Name' }

    assert_response :unauthorized

    response_body = JSON.parse(response.body)
    assert_equal 'Authorization token required', response_body['error']
  end

  test 'should reject update with invalid visibility' do
    project = @user.projects.create!(
      name: 'Test Project',
      version: '1.0.0',
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    patch api_v1_project_path(project),
          params: { visibility: 'invalid' },
          headers: @headers

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert_includes response_body['details'], 'Visibility must be either "private" or "public"'
  end

  test 'should reject update with blank project name' do
    project = @user.projects.create!(
      name: 'Test Project',
      version: '1.0.0',
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    patch api_v1_project_path(project),
          params: { name: '' },
          headers: @headers

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert_includes response_body['details'], 'Project name cannot be blank'
  end

  # === DESTROY ACTION TESTS ===

  test 'should delete own project' do
    project = @user.projects.create!(
      name: 'Project to Delete',
      version: '1.0.0',
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    project_id = project.id

    delete api_v1_project_path(project), headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    assert_equal 'Project deleted successfully', response_body['message']
    assert_equal project_id, response_body['project']['id']
    assert_equal 'Project to Delete', response_body['project']['name']
    assert_equal @user.id, response_body['project']['user_id']
    assert_not_nil response_body['project']['owner']

    # Verify project is actually deleted from database
    assert_nil Project.find_by(id: project_id)
  end

  test 'should delete own public project' do
    project = @user.projects.create!(
      name: 'Public Project to Delete',
      version: '1.0.0',
      visibility: :shared,
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    project_id = project.id

    delete api_v1_project_path(project), headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    assert_equal 'Project deleted successfully', response_body['message']
    assert_equal 'shared', response_body['project']['visibility']

    # Verify project is actually deleted from database
    assert_nil Project.find_by(id: project_id)
  end

  test 'should not delete other user project' do
    other_user = User.create!(
      email: 'other@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Other',
      last_name: 'User'
    )

    project = other_user.projects.create!(
      name: 'Other User Project',
      version: '1.0.0',
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    project_id = project.id

    delete api_v1_project_path(project), headers: @headers

    assert_response :forbidden

    response_body = JSON.parse(response.body)
    assert_equal 'Access denied. You can only delete your own projects.', response_body['error']

    # Verify project is NOT deleted from database
    assert_not_nil Project.find_by(id: project_id)
  end

  test 'should not delete other user public project' do
    other_user = User.create!(
      email: 'other@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Other',
      last_name: 'User'
    )

    project = other_user.projects.create!(
      name: 'Other User Public Project',
      version: '1.0.0',
      visibility: :shared,
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    project_id = project.id

    delete api_v1_project_path(project), headers: @headers

    assert_response :forbidden

    response_body = JSON.parse(response.body)
    assert_equal 'Access denied. You can only delete your own projects.', response_body['error']

    # Verify project is NOT deleted from database
    assert_not_nil Project.find_by(id: project_id)
  end

  test 'should return not found for non-existent project deletion' do
    delete api_v1_project_path(99999), headers: @headers

    assert_response :not_found

    response_body = JSON.parse(response.body)
    assert_equal 'Project not found', response_body['error']
  end

  test 'should reject delete without authentication' do
    project = @user.projects.create!(
      name: 'Test Project',
      version: '1.0.0',
      board_config: { dimensions: {}, appearance: {} },
      nails: { '0,0' => { id: 1 } }
    )

    project_id = project.id

    delete api_v1_project_path(project)

    assert_response :unauthorized

    response_body = JSON.parse(response.body)
    assert_equal 'Authorization token required', response_body['error']

    # Verify project is NOT deleted from database
    assert_not_nil Project.find_by(id: project_id)
  end

  test 'should include project data in delete response' do
    project = @user.projects.create!(
      name: 'Detailed Project',
      version: '2.5.0',
      visibility: :personal,
      board_config: { dimensions: { width: 800 }, appearance: { color: 'oak' } },
      nails: { '10,20' => { id: 1, type: 'corner' } }
    )

    delete api_v1_project_path(project), headers: @headers

    assert_response :ok

    response_body = JSON.parse(response.body)
    project_data = response_body['project']

    assert_equal 'Detailed Project', project_data['name']
    assert_equal '2.5.0', project_data['version']
    assert_equal 'personal', project_data['visibility']
    assert_not_nil project_data['created_at']
    assert_not_nil project_data['updated_at']
    assert_equal @user.full_name, project_data['owner']['full_name']
  end

  # === CREATE ACTION TESTS ===

  test 'should create project with valid data' do
    post api_v1_projects_path,
         params: @valid_project_params,
         headers: @headers

    assert_response :created

    response_body = JSON.parse(response.body)
    assert_equal 'Project created successfully', response_body['message']
    
    project = response_body['project']
    assert_not_nil project['id']
    assert_equal @user.id, project['user_id']
    assert_equal 'MDF Grid Test Project', project['name']
    assert_equal '1.0.0', project['version']
    assert_not_nil project['board_config']
    assert_not_nil project['nails']
    assert_not_nil project['created_at']
    assert_not_nil project['updated_at']

    # Verify project was actually created in database
    created_project = Project.find(project['id'])
    assert_equal @user.id, created_project.user_id
    assert_equal 'MDF Grid Test Project', created_project.name
  end

  test 'should create project with default version when not provided' do
    params = @valid_project_params.dup
    params[:project].delete(:version)

    post api_v1_projects_path,
         params: params,
         headers: @headers

    assert_response :created

    response_body = JSON.parse(response.body)
    project = response_body['project']
    assert_equal '1.0.0', project['version']
  end

  test 'should reject project creation without authentication' do
    post api_v1_projects_path,
         params: @valid_project_params

    assert_response :unauthorized

    response_body = JSON.parse(response.body)
    assert_equal 'Authorization token required', response_body['error']
  end

  test 'should reject project creation with invalid token' do
    headers = { 'Authorization' => 'Bearer invalid_token' }

    post api_v1_projects_path,
         params: @valid_project_params,
         headers: headers

    assert_response :unauthorized

    response_body = JSON.parse(response.body)
    assert_equal 'Invalid or expired token', response_body['error']
  end

  test 'should reject project creation without name' do
    params = @valid_project_params.dup
    params[:project][:name] = ''

    post api_v1_projects_path,
         params: params,
         headers: @headers

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert_equal 'Project creation failed', response_body['error']
    assert_includes response_body['details'], 'Project name is required'
  end

  test 'should reject project creation without board_config' do
    params = @valid_project_params.dup
    params[:project].delete(:board_config)

    post api_v1_projects_path,
         params: params,
         headers: @headers

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert_equal 'Project creation failed', response_body['error']
    assert_includes response_body['details'], 'Board config is required'
  end

  test 'should reject project creation without nails data' do
    params = @valid_project_params.dup
    params[:project].delete(:nails)

    post api_v1_projects_path,
         params: params,
         headers: @headers

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert_equal 'Project creation failed', response_body['error']
    assert_includes response_body['details'], 'Nails data is required'
  end

  test 'should reject project creation with invalid board_config structure' do
    params = @valid_project_params.dup
    params[:project][:board_config] = { invalid: 'structure' }

    post api_v1_projects_path,
         params: params,
         headers: @headers

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert_equal 'Project creation failed', response_body['error']
    assert_includes response_body['details'], 'Board config must include dimensions'
  end

  test 'should reject project creation with invalid nail position format' do
    params = @valid_project_params.dup
    params[:project][:nails] = { 'invalid_position' => { id: 1 } }

    post api_v1_projects_path,
         params: params,
         headers: @headers

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert_equal 'Project creation failed', response_body['error']
    assert_includes response_body['details'], "Invalid nail position format: invalid_position. Expected format: 'x,y'"
  end
end
