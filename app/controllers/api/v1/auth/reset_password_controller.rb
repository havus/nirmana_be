class Api::V1::Auth::ResetPasswordController < ApplicationController
  # POST /api/v1/auth/reset_password
  def create
    result = ResetPasswordService.call(
      token: params[:token],
      new_password: params[:new_password],
      new_password_confirmation: params[:new_password_confirmation]
    )

    if result.success?
      render json: {
        message: 'Password has been reset successfully',
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
        error: 'Password reset failed',
        details: result.errors
      }, status: :unprocessable_entity
    end
  end
end
