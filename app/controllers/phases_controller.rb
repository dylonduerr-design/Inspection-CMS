class PhasesController < ApplicationController
  before_action :set_project
  before_action :set_phase, only: %i[ update destroy ]

  # POST /projects/:project_id/phases
  def create
    @phase = @project.phases.build(phase_params)

    if @phase.save
      redirect_to project_path(@project, anchor: "phases"), notice: "Phase was successfully created."
    else
      redirect_to project_path(@project, anchor: "phases"), alert: @phase.errors.full_messages.to_sentence
    end
  end

  # PATCH/PUT /projects/:project_id/phases/:id
  def update
    if @phase.update(phase_params)
      redirect_to project_path(@project, anchor: "phases"), notice: "Phase was successfully updated."
    else
      redirect_to project_path(@project, anchor: "phases"), alert: @phase.errors.full_messages.to_sentence
    end
  end

  # DELETE /projects/:project_id/phases/:id
  def destroy
    if @phase.destroy
      redirect_to project_path(@project, anchor: "phases"), notice: "Phase was successfully removed."
    else
      redirect_to project_path(@project, anchor: "phases"), alert: @phase.errors.full_messages.to_sentence
    end
  end

  private

    def set_project
      @project = Project.find(params[:project_id])
    end

    def set_phase
      @phase = @project.phases.find(params[:id])
    end

    def phase_params
      params.require(:phase).permit(:name)
    end
end
