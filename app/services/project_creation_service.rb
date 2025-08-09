class ProjectCreationService
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

  def self.call(user:, params:)
    new(user, params).call
  end

  def initialize(user, params)
    @user = user
    @params = params.to_h
  end

  def call
    return failure_result(['User is required']) unless @user
    return failure_result(['Project name is required']) if @params[:name].blank?
    return failure_result(['Board config is required']) if @params[:board_config].blank?
    return failure_result(['Nails data is required']) if @params[:nails].blank?

    # Validate board_config structure
    board_config_errors = validate_board_config(@params[:board_config])
    return failure_result(board_config_errors) if board_config_errors.any?

    # Validate nails structure
    nails_errors = validate_nails(@params[:nails])
    return failure_result(nails_errors) if nails_errors.any?

    ApplicationRecord.transaction do
      project = @user.projects.create!(
        name: @params[:name],
        version: @params[:version] || '1.0.0',
        board_config: @params[:board_config],
        nails: @params[:nails]
      )
      success_result(project)
    end
  rescue ActiveRecord::RecordInvalid => e
    failure_result(e.record.errors.full_messages)
  rescue StandardError => e
    Rails.logger.error "ProjectCreationService failed: #{e.message}"
    failure_result(['Project creation failed. Please try again.'])
  end

  private

  def validate_board_config(board_config)
    errors = []
    
    unless board_config.is_a?(Hash)
      errors << 'Board config must be a valid object'
      return errors
    end

    # Validate required numeric fields
    required_numeric_fields = ['dotsCountHorizontal', 'dotsCountVertical', 'marginBetweenNails', 'paddingBoard']
    required_numeric_fields.each do |field|
      unless board_config[field].present?
        errors << "Board config must include #{field}"
      else
        value = board_config[field]
        unless value.is_a?(Numeric) && value > 0
          errors << "#{field} must be a positive number"
        end
      end
    end

    # Validate boardColor
    unless board_config['boardColor'].present?
      errors << 'Board config must include boardColor'
    else
      board_color = board_config['boardColor']
      unless board_color.is_a?(String) && board_color.match?(/^#[0-9A-Fa-f]{6}$/)
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
        errors << "name: #{position}. Expected format: 'x,y'"
        break
      end
    end

    errors
  end

  def success_result(project)
    Result.new(success: true, project: project)
  end

  def failure_result(errors)
    Result.new(success: false, errors: Array(errors))
  end
end
