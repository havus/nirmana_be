class UserUpdateService
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

  def initialize(user_uid, current_user, params)
    @user_uid = user_uid
    @current_user = current_user
    @params = params || {}
  end

  def call
    return failure_result('User UID is required', :bad_request) if @user_uid.blank?
    return failure_result('User authentication is required', :unauthorized) unless @current_user

    begin
      user = find_user
      return failure_result('User not found', :not_found) unless user
      return failure_result('Access denied. You can only update your own profile.', :forbidden) unless can_update_user?(user)

      # Filter and validate parameters
      filtered_params = filter_allowed_params
      return failure_result('No valid parameters provided for update', :bad_request) if filtered_params.empty?

      # Validate the parameters
      validation_errors = validate_params(filtered_params, user)
      return failure_result(validation_errors.first, :unprocessable_entity) if validation_errors.any?

      # Update the user
      ApplicationRecord.transaction do
        user.update!(filtered_params)
        success_result('User profile updated successfully', user)
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "UserUpdateService validation failed: #{e.message}"
      failure_result("Validation failed: #{e.record.errors.full_messages.join(', ')}", :unprocessable_entity)
    rescue StandardError => e
      Rails.logger.error "UserUpdateService failed: #{e.message}"
      failure_result('Failed to update user profile. Please try again.', :internal_server_error)
    end
  end

  private

  def find_user
    User.find_by(uid: @user_uid)
  end

  def can_update_user?(user)
    @current_user.id == user.id
  end

  def filter_allowed_params
    allowed_fields = %w[username first_name last_name phone description date_of_birth]
    @params.select { |key, value| allowed_fields.include?(key.to_s) && value.present? }
  end

  def validate_params(params, user)
    errors = []

    if params['username']
      if params['username'].length > 50
        errors << 'Username cannot be longer than 50 characters'
      end
      # Check for username uniqueness (excluding current user)
      existing_user = User.where(username: params['username']).where.not(id: user.id).first
      if existing_user
        errors << 'Username is already taken'
      end
    end

    if params['first_name']
      if params['first_name'].length > 100
        errors << 'First name cannot be longer than 100 characters'
      end
    end

    if params['last_name']
      if params['last_name'].length > 100
        errors << 'Last name cannot be longer than 100 characters'
      end
    end

    if params['phone']
      if params['phone'].length > 20
        errors << 'Phone cannot be longer than 20 characters'
      end
    end

    if params['description']
      if params['description'].length > 1000
        errors << 'Description cannot be longer than 1000 characters'
      end
    end

    if params['date_of_birth']
      begin
        Date.parse(params['date_of_birth'].to_s)
      rescue ArgumentError
        errors << 'Date of birth must be a valid date'
      end
    end

    errors
  end

  def success_result(message, data)
    Result.new(success: true, message: message, data: data)
  end

  def failure_result(message, status)
    Result.new(success: false, message: message, status: status)
  end
end
