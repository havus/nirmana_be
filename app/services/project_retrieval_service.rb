class ProjectRetrievalService
  class Result
    attr_reader :success, :project, :errors

    def initialize(success:, project: nil, errors: [])
      @success = success
      @project = project
      @errors = errors
    end

    def success?
      @success
    end
  end

  def self.call(project_id:, current_user:)
    new(project_id, current_user).call
  end

  def initialize(project_id, current_user)
    @project_id = project_id
    @current_user = current_user
  end

  def call
    return failure_result(['Project ID is required']) if @project_id.blank?
    return failure_result(['User authentication is required']) unless @current_user

    begin
      project = find_project
      return failure_result(['Project not found']) unless project
      return failure_result(['Access denied']) unless can_access_project?(project)

      formatted_project = format_project(project)
      success_result(formatted_project)
    rescue StandardError => e
      Rails.logger.error "ProjectRetrievalService failed: #{e.message}"
      failure_result(['Failed to retrieve project. Please try again.'])
    end
  end

  private

  def find_project
    Project.find_by(id: @project_id)
  end

  def can_access_project?(project)
    # User can access their own projects regardless of visibility
    return true if project.user_id == @current_user.id
     # User can access other users' shared projects
    return true if project.shared?

    # Cannot access other users' personal projects
    false
  end

  def format_project(project)
    {
      id: project.id,
      user_id: project.user_id,
      name: project.name,
      version: project.version,
      visibility: project.visibility,
      board_config: project.board_config,
      nails: project.nails,
      created_at: project.created_at,
      updated_at: project.updated_at,
      owner: {
        id: project.user.id,
        uid: project.user.uid,
        first_name: project.user.first_name,
        last_name: project.user.last_name,
        full_name: project.user.full_name
      }
    }
  end

  def success_result(project)
    Result.new(success: true, project: project)
  end

  def failure_result(errors)
    Result.new(success: false, errors: Array(errors))
  end
end
