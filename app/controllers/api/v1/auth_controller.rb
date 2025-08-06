class Api::V1::AuthController < ApplicationController
  before_action :authenticate_user!, only: [:change_password]

  # POST /api/v1/sign_up
  def sign_up
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

  # POST /api/v1/sign_in
  def sign_in
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

  # POST /api/v1/verify_email
  def verify_email
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

  # POST /api/v1/forgot_password
  def forgot_password
    email = params[:email]

    if email.blank?
      render json: {
        error: 'Email is required'
      }, status: :bad_request
      return
    end

    result = ForgotPasswordService.call(email: email)

    if result.success?
      render json: {
        message: 'If an account with that email exists, a password reset link has been sent.'
      }, status: :ok
    else
      # For security reasons, we don't reveal if the email exists or not
      # We return the same message regardless of success or failure
      render json: {
        message: 'If an account with that email exists, a password reset link has been sent.'
      }, status: :ok
    end
  end

  # POST /api/v1/reset_password
  def reset_password
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

  # POST /api/v1/change_password
  def change_password
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

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :first_name, :last_name, :phone)
  end
end
