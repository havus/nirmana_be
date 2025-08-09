class Api::V1::ProjectsController < ApplicationController
  before_action :authenticate_user!

  # GET /api/v1/projects
  def index
    result = ProjectListingService.call(
      user: current_user,
      page_number: params[:page_number],
      page_size: params[:page_size]
    )

    if result.success?
      render json: {
        projects: result.projects,
        pagination: result.pagination
      }, status: :ok
    else
      render json: {
        error: 'Failed to retrieve projects',
        details: result.errors
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/projects/:id
  def show
    result = ProjectRetrievalService.call(
      project_id: params[:id],
      current_user: current_user
    )

    if result.success?
      render json: {
        project: result.project
      }, status: :ok
    else
      error_status = result.errors.include?('Project not found') ? :not_found : 
                    result.errors.include?('Access denied') ? :forbidden : 
                    :unprocessable_entity

      render json: {
        error: result.errors.first || 'Failed to retrieve project',
        details: result.errors
      }, status: error_status
    end
  end

  # PATCH /api/v1/projects/:id
  def update
    result = ProjectUpdateService.call(
      project_id: params[:id],
      current_user: current_user,
      params: update_params
    )

    if result.success?
      render json: {
        message: 'Project updated successfully',
        project: result.project
      }, status: :ok
    else
      error_status = result.errors.include?('Project not found') ? :not_found : 
                    result.errors.include?('Access denied. You can only update your own projects.') ? :forbidden : 
                    :unprocessable_entity

      render json: {
        error: result.errors.first || 'Failed to update project',
        details: result.errors
      }, status: error_status
    end
  end

  # DELETE /api/v1/projects/:id
  def destroy
    result = ProjectDeletionService.new(params[:id], current_user).call

    if result.success?
      render json: {
        message: result.message,
      }, status: :no_content
    else
      render json: { error: result.message }, status: result.status
    end
  end

  # POST /api/v1/projects
  def create
    result = ProjectCreationService.call(
      user: current_user,
      params: project_params
    )

    if result.success?
      render json: {
        message: 'Project created successfully',
        project: {
          id: result.project.id,
          user_id: result.project.user_id,
          name: result.project.name,
          version: result.project.version,
          board_config: result.project.board_config,
          nails: result.project.nails,
          created_at: result.project.created_at,
          updated_at: result.project.updated_at
        }
      }, status: :created
    else
      render json: {
        error: 'Project creation failed',
        details: result.errors
      }, status: :unprocessable_entity
    end
  end

  private

  def project_params
    params.require(:project).permit(
      :name,
      :version,
      board_config: {},
      nails: {}
    )
  end

  def update_params
    # Allow any subset of these fields to be updated
    permitted = params.permit(
      :name,
      :version,
      :visibility,
      board_config: {},
      nails: {}
    )
    
    # Only return fields that are actually present in the request
    permitted.to_h.select { |key, value| params.has_key?(key) }
  end
end
