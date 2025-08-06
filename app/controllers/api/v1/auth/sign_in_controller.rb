class Api::V1::Auth::SignInController < ApplicationController
  # POST /api/v1/auth/sign_in
  def create
    result = UserLoginService.call(
      email: params[:email],
      password: params[:password],
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    if result.success?
      render json: {
        message: 'Signed in successfully',
        user: {
          id: result.user.id,
          uid: result.user.uid,
          email: result.user.email,
          first_name: result.user.first_name,
          last_name: result.user.last_name,
          email_verified: result.user.email_verified?
        },
        session: {
          token: result.session.session_token,
          expires_at: result.session.expires_at
        }
      }, status: :ok
    else
      error = result.errors.first
      status = error == 'Email and password are required' ? :bad_request : :unauthorized
      
      render json: {
        error: error || 'Failed to sign in'
      }, status: status
    end
  end
end
