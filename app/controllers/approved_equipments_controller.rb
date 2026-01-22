class ApprovedEquipmentsController < ApplicationController
  before_action :set_project

  def create
    @approved_equipment = @project.approved_equipments.build(approved_equipment_params)
    
    if @approved_equipment.save
      redirect_to edit_project_path(@project), notice: "Equipment added successfully."
    else
      redirect_to edit_project_path(@project), alert: "Failed to add equipment: #{@approved_equipment.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    @approved_equipment = @project.approved_equipments.find(params[:id])
    @approved_equipment.destroy
    redirect_to edit_project_path(@project), notice: "Equipment removed successfully."
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def approved_equipment_params
    params.require(:approved_equipment).permit(:name, :category) if params[:approved_equipment].present?
    params.permit(:name, :category) unless params[:approved_equipment].present?
  end
end
