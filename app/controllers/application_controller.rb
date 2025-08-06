class ApplicationController < ActionController::API
  # Add CSRF protection for API
  # protect_from_forgery with: :null_session

  # Add rate limiting (consider using rack-attack gem)

  private

  def render_error(message, status = :bad_request)
    render json: { error: message }, status: status
  end
end
