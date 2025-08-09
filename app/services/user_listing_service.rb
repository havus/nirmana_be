class UserListingService
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

  DEFAULT_PAGE_SIZE = 20
  MAX_PAGE_SIZE = 100

  def initialize(current_user, page_number = 1, page_size = DEFAULT_PAGE_SIZE)
    @current_user = current_user
    @page_number = page_number
    @page_size = page_size
  end

  def call
    return failure_result('User authentication is required', :unauthorized) unless @current_user

    # Validate and normalize pagination parameters
    normalized_page_number = normalize_page_number(@page_number)
    normalized_page_size = normalize_page_size(@page_size)

    begin
      offset = (normalized_page_number - 1) * normalized_page_size

      users = User.verified
                  .order(:first_name, :last_name, :created_at)
                  .limit(normalized_page_size)
                  .offset(offset)

      total_count = User.verified.count
      total_pages = (total_count.to_f / normalized_page_size).ceil

      pagination_info = {
        page_number: normalized_page_number,
        page_size: normalized_page_size,
        total_count: total_count,
        total_pages: total_pages,
        has_next_page: normalized_page_number < total_pages,
        has_previous_page: normalized_page_number > 1
      }

      users_data = users.map { |user| format_user(user) }

      success_result('Users retrieved successfully', {
        users: users_data,
        pagination: pagination_info
      })
    rescue StandardError => e
      Rails.logger.error "UserListingService failed: #{e.message}"
      failure_result('Failed to retrieve users. Please try again.', :internal_server_error)
    end
  end

  private

  def normalize_page_number(page_number)
    page_number.to_i.positive? ? page_number.to_i : 1
  end

  def normalize_page_size(page_size)
    size = page_size.to_i
    return DEFAULT_PAGE_SIZE if size <= 0
    [size, MAX_PAGE_SIZE].min
  end

  def format_user(user)
    {
      id: user.id,
      uid: user.uid,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      full_name: user.full_name,
      phone: user.phone,
      description: user.description,
      date_of_birth: user.date_of_birth,
      avatar_url: user.avatar_url,
      status: user.status,
      email_verified_at: user.email_verified_at,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end

  def success_result(message, data)
    Result.new(success: true, message: message, data: data)
  end

  def failure_result(message, status)
    Result.new(success: false, message: message, status: status)
  end
end
