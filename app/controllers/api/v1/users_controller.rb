class Api::V1::UsersController < ApplicationController
  before_action :authenticate_user!, only: [:update]

  # GET /api/v1/users/:uid
  def show
    result = UserRetrievalService.new(params[:uid]).call

    if result.success?
      render json: {
        message: result.message,
        user: format_user_response(result.data)
      }, status: :ok
    else
      render json: { error: result.message }, status: result.status
    end
  end

  # PUT /api/v1/users/:uid
  def update
    result = UserUpdateService.new(params[:uid], current_user, update_params).call

    if result.success?
      render json: {
        message: result.message,
        user: format_user_response(result.data)
      }, status: :ok
    else
      render json: { error: result.message }, status: result.status
    end
  end

  private

  def update_params
    params.permit(:username, :first_name, :last_name, :phone, :description, :date_of_birth)
  end

  def format_user_response(user)
    {
      id: user.id,
      uid: user.uid,
      username: user.username,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      full_name: user.full_name,
      phone: user.phone,
      description: user.description,
      date_of_birth: user.date_of_birth,
      avatar_url: user.avatar_url,
      status: user.status,
      email_verified_at: user.email_verified_at,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end
end
