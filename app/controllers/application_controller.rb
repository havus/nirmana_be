class ApplicationController < ActionController::API
  # Add CSRF protection for API
  # protect_from_forgery with: :null_session

  # Add rate limiting (consider using rack-attack gem)

  before_action :authenticate_user!, only: []

  private

  def render_error(message, status = :bad_request)
    render json: { error: message }, status: status
  end

  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last

    unless token
      render json: { error: 'Authorization token required' }, status: :unauthorized
      return
    end

    session = UserSession.find_active_session(token)

    unless session
      render json: { error: 'Invalid or expired token' }, status: :unauthorized
      return
    end

    @current_user = session.user
  end

  def current_user
    @current_user
  end

  def user_signed_in?
    current_user.present?
  end
end
