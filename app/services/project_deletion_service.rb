class ProjectDeletionService
  class Result
    attr_reader :success, :message, :data, :status

    def initialize(success:, message: nil, data: nil, status: nil)
      @success = success
      @message = message
      @data = data
      @status = status
    end

    def success?
      @success
    end
  end

  def initialize(project_id, current_user)
    @project_id = project_id
    @current_user = current_user
  end

  def call
    return failure_result('Project ID is required', :bad_request) if @project_id.blank?
    return failure_result('User authentication is required', :unauthorized) unless @current_user

    begin
      project = find_project
      return failure_result('Project not found', :not_found) unless project
      return failure_result('Access denied. You can only delete your own projects.', :forbidden) unless can_delete_project?(project)

      # Store project data before deletion for response
      project_data = format_project(project)

      ApplicationRecord.transaction do
        project.destroy!
        success_result('Project deleted successfully', project_data)
      end
    rescue ActiveRecord::RecordNotDestroyed => e
      Rails.logger.error "ProjectDeletionService failed to destroy project: #{e.message}"
      failure_result('Failed to delete project. Please try again.', :unprocessable_entity)
    rescue StandardError => e
      Rails.logger.error "ProjectDeletionService failed: #{e.message}"
      failure_result('Failed to delete project. Please try again.', :internal_server_error)
    end
  end

  private

  def find_project
    Project.find_by(id: @project_id)
  end

  def can_delete_project?(project)
    # Only the owner can delete their project
    project.user_id == @current_user.id
  end

  def format_project(project)
    {
      id: project.id,
      user_id: project.user_id,
      name: project.name,
      version: project.version,
      visibility: project.visibility,
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

  def success_result(message, data)
    Result.new(success: true, message: message, data: data)
  end

  def failure_result(message, status)
    Result.new(success: false, message: message, status: status)
  end
end
