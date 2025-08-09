class ProjectListingService
  class Result
    attr_reader :success, :projects, :pagination, :errors

    def initialize(success:, projects: [], pagination: {}, errors: [])
      @success = success
      @projects = projects
      @pagination = pagination
      @errors = errors
    end

    def success?
      @success
    end
  end

  def self.call(user:, page_number: 1, page_size: 20)
    new(user, page_number, page_size).call
  end

  def initialize(user, page_number, page_size)
    @user = user
    @page_number = page_number
    @page_size = page_size
  end

  def call
    return failure_result(['User is required']) unless @user

    # Validate and normalize pagination parameters
    normalized_page_number = normalize_page_number(@page_number)
    normalized_page_size = normalize_page_size(@page_size)

    begin
      offset = (normalized_page_number - 1) * normalized_page_size

      projects = @user.projects
                      .order(created_at: :desc)
                      .limit(normalized_page_size)
                      .offset(offset)

      total_count = @user.projects.count
      total_pages = (total_count.to_f / normalized_page_size).ceil

      formatted_projects = projects.map do |project|
        {
          id: project.id,
          user_id: project.user_id,
          name: project.name,
          version: project.version,
          board_config: project.board_config,
          nails: project.nails,
          created_at: project.created_at,
          updated_at: project.updated_at
        }
      end

      pagination_info = {
        page_number: normalized_page_number,
        page_size: normalized_page_size,
        total_count: total_count,
        total_pages: total_pages,
        has_next_page: normalized_page_number < total_pages,
        has_previous_page: normalized_page_number > 1
      }

      success_result(formatted_projects, pagination_info)
    rescue StandardError => e
      Rails.logger.error "ProjectListingService failed: #{e.message}"
      failure_result(['Failed to retrieve projects. Please try again.'])
    end
  end

  private

  def normalize_page_number(page_number)
    # Convert to integer and ensure it's at least 1
    normalized = page_number.to_i
    normalized < 1 ? 1 : normalized
  end

  def normalize_page_size(page_size)
    # Convert to integer, ensure it's between 1 and 100
    normalized = page_size.to_i
    return 1 if normalized < 1
    return 100 if normalized > 100
    normalized
  end

  def success_result(projects, pagination)
    Result.new(success: true, projects: projects, pagination: pagination)
  end

  def failure_result(errors)
    Result.new(success: false, errors: Array(errors))
  end
end
