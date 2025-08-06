class Api::V1::Auth::ForgotPasswordController < ApplicationController
  # POST /api/v1/auth/forgot_password
  def create
    email = params[:email]

    result = ForgotPasswordService.call(email: email)

    if result.success?
      render json: {
        message: 'If an account with that email exists, a password reset link has been sent.'
      }, status: :ok
    else
      # Check if it's a validation error that should return bad_request
      if result.errors.include?('Email is required')
        render json: {
          error: result.errors.first
        }, status: :bad_request
      else
        # For security reasons, we don't reveal if the email exists or not
        # We return the same message regardless of success or failure for user-related errors
        render json: {
          message: 'If an account with that email exists, a password reset link has been sent.'
        }, status: :ok
      end
    end
  end
end
