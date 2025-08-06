class Api::V1::Auth::ChangePasswordController < ApplicationController
  before_action :authenticate_user!

  # POST /api/v1/auth/change_password
  def create
    result = PasswordChangeService.call(
      user: current_user,
      current_password: params[:current_password],
      new_password: params[:new_password],
      new_password_confirmation: params[:new_password_confirmation]
    )

    if result.success?
      render json: {
        message: 'Password changed successfully',
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
        error: 'Password change failed',
        details: result.errors
      }, status: :unprocessable_entity
    end
  end
end
