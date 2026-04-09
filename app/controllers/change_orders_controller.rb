class ChangeOrdersController < ApplicationController
  before_action :set_project
  before_action :set_change_order, only: [:update, :destroy]
  before_action :require_admin!

  def create
    @change_order = @project.change_orders.build(change_order_params)

    if @change_order.save
      redirect_to project_path(@project, anchor: "change-orders"), notice: "Change Order ##{@change_order.number} created."
    else
      load_project_collections
      render "projects/show", status: :unprocessable_entity
    end
  end

  def update
    if @change_order.update(change_order_params)
      redirect_to project_path(@project, anchor: "change-orders"), notice: "Change Order ##{@change_order.number} updated."
    else
      load_project_collections
      render "projects/show", status: :unprocessable_entity
    end
  end

  def destroy
    if @change_order.placed_quantities.exists?
      redirect_to project_path(@project, anchor: "change-orders"),
                  alert: "Cannot delete CO ##{@change_order.number} — it has placed quantities recorded against it."
    else
      @change_order.destroy!
      redirect_to project_path(@project, anchor: "change-orders"),
                  notice: "Change Order ##{@change_order.number} deleted."
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_change_order
    @change_order = @project.change_orders.find(params[:id])
  end

  def change_order_params
    params.require(:change_order).permit(:number, :description, :status, :approved_date)
  end

  def require_admin!
    return if current_user&.admin?
    redirect_to project_path(@project), alert: "You are not authorized to manage change orders."
  end

  def load_project_collections
    @bid_items = @project.bid_items.includes(:spec_item).order(:code)
    @asphalt_lots = @project.asphalt_lots.includes(:asphalt_sublots, :core_generations).order(:lot_number)
    @phases = @project.phases.left_joins(:reports)
                      .select('phases.*, COUNT(reports.id) AS reports_count')
                      .group('phases.id')
                      .order(:name)
    @approved_equipments = @project.approved_equipments.order(:name)
    @change_orders = @project.change_orders.order(:number)
  end
end
