class Api::V1::Auth::SignUpController < ApplicationController
  # POST /api/v1/auth/sign_up
  def create
    result = UserRegistrationService.call(user_params)

    if result.success?
      render json: {
        message: 'User created successfully. Please check your email to verify your account.',
        user: {
          id: result.user.id,
          uid: result.user.uid,
          email: result.user.email,
          first_name: result.user.first_name,
          last_name: result.user.last_name,
          email_verified: result.user.email_verified?
        }
      }, status: :created
    else
      render json: {
        error: 'User registration failed',
        details: result.errors
      }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :first_name, :last_name, :phone)
  end
end
