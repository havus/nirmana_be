class Api::V1::Auth::VerifyEmailController < ApplicationController
  # POST /api/v1/auth/verify_email
  def create
    token = params[:token]

    if token.blank?
      render json: {
        error: 'Token is required'
      }, status: :bad_request
      return
    end

    result = EmailVerificationService.call(token: token)

    if result.success?
      render json: {
        message: 'Email verified successfully',
        user: {
          id: result.user.id,
          uid: result.user.uid,
          email: result.user.email,
          first_name: result.user.first_name,
          last_name: result.user.last_name,
          email_verified: result.user.email_verified?
        }
      }, status: :ok
    else
      render json: {
        error: result.errors.first || 'Failed to verify email'
      }, status: :unprocessable_entity
    end
  end
end
