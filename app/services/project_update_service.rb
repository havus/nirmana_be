class ProjectUpdateService
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

  def self.call(project_id:, current_user:, params:)
    new(project_id, current_user, params).call
  end

  def initialize(project_id, current_user, params)
    @project_id = project_id
    @current_user = current_user
    @params = params
  end

  def call
    return failure_result(['Project ID is required']) if @project_id.blank?
    return failure_result(['User authentication is required']) unless @current_user

    begin
      project = find_project
      return failure_result(['Project not found']) unless project
      return failure_result(['Access denied. You can only update your own projects.']) unless can_update_project?(project)

      # Validate parameters before updating
      validation_errors = validate_update_params(@params)
      return failure_result(validation_errors) if validation_errors.any?

      ApplicationRecord.transaction do
        update_project_fields(project, @params)
        project.save!
        formatted_project = format_project(project)
        success_result(formatted_project)
      end
    rescue ActiveRecord::RecordInvalid => e
      failure_result(e.record.errors.full_messages)
    rescue StandardError => e
      Rails.logger.error "ProjectUpdateService failed: #{e.message}"
      failure_result(['Failed to update project. Please try again.'])
    end
  end

  private

  def find_project
    Project.find_by(id: @project_id)
  end

  def can_update_project?(project)
    # Only the owner can update their project
    project.user_id == @current_user.id
  end

  def validate_update_params(params)
    errors = []

    # Validate name if present
    if params.key?(:name)
      if params[:name].blank?
        errors << 'Project name cannot be blank'
      elsif params[:name].length > 255
        errors << 'Project name cannot exceed 255 characters'
      end
    end

    # Validate version if present
    if params.key?(:version)
      if params[:version].blank?
        errors << 'Version cannot be blank'
      elsif params[:version].length > 10
        errors << 'Version cannot exceed 10 characters'
      end
    end

    # Validate visibility if present
    if params.key?(:visibility)
      unless %w[personal shared].include?(params[:visibility])
        errors << 'Visibility must be either "personal" or "shared"'
      end
    end

    # Validate board_config if present
    if params.key?(:board_config)
      board_config_errors = validate_board_config(params[:board_config])
      errors.concat(board_config_errors)
    end

    # Validate nails if present
    if params.key?(:nails)
      nails_errors = validate_nails(params[:nails])
      errors.concat(nails_errors)
    end

    errors
  end

  def validate_board_config(board_config)
    errors = []
    
    unless board_config.is_a?(Hash)
      errors << 'Board config must be a valid object'
      return errors
    end

    # Validate numeric fields if they are being updated
    numeric_fields = ['dotsCountHorizontal', 'dotsCountVertical', 'marginBetweenNails', 'paddingBoard']
    numeric_fields.each do |field|
      if board_config.key?(field)
        value = board_config[field]
        if value.blank?
          errors << "#{field} cannot be blank"
        elsif !value.is_a?(Numeric) || value <= 0
          errors << "#{field} must be a positive number"
        end
      end
    end

    # Validate boardColor if it's being updated
    if board_config.key?('boardColor')
      board_color = board_config['boardColor']
      if board_color.blank?
        errors << 'boardColor cannot be blank'
      elsif !board_color.is_a?(String) || !board_color.match?(/^#[0-9A-Fa-f]{6}$/)
        errors << 'boardColor must be a valid hex color (e.g., #8B4513)'
      end
    end

    errors
  end

  def validate_nails(nails)
    errors = []
    
    unless nails.is_a?(Hash)
      errors << 'Nails data must be a valid object'
      return errors
    end

    # Validate nail position format (should be like "x,y": {...})
    nails.each_key do |position|
      unless position.match?(/^\d+,\d+$/)
        errors << "Invalid nail position format: #{position}. Expected format: 'x,y'"
        break
      end
    end

    errors
  end

  def update_project_fields(project, params)
    # Only update fields that are present in the request
    project.name = params[:name] if params.key?(:name)
    project.version = params[:version] if params.key?(:version)
    project.visibility = params[:visibility] if params.key?(:visibility)
    project.board_config = params[:board_config] if params.key?(:board_config)
    project.nails = params[:nails] if params.key?(:nails)
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
