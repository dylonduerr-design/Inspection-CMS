class BulkSetupsController < ApplicationController
  before_action :set_project_and_lot

  def new
    @num_sublots = params[:num_sublots]&.to_i || 1
    @lanes_per_sublot = params[:lanes_per_sublot]&.to_i || 1
    @starting_position = (@asphalt_lot.asphalt_sublots.maximum(:position) || 0) + 1
  end

  def create
    if params[:sublots].blank?
      redirect_to project_asphalt_lot_path(@project, @asphalt_lot), alert: "No sublot data provided"
      return
    end

    starting_position = (@asphalt_lot.asphalt_sublots.maximum(:position) || 0)

    AsphaltLot.transaction do
      params[:sublots].each do |idx, sublot_data|
        sublot = @asphalt_lot.asphalt_sublots.create!(
          position: starting_position + idx.to_i + 1,
          name: "Sublot #{starting_position + idx.to_i + 1}"
        )

        next if sublot_data[:lanes].blank?

        sublot_data[:lanes].each do |lane_idx, lane_data|
          next if lane_data[:length_ft].blank?

          sublot.asphalt_lanes.create!(
            position: lane_idx.to_i + 1,
            name: "Lane #{lane_idx.to_i + 1}",
            length_ft: lane_data[:length_ft],
            width_ft: lane_data[:width_ft]
          )
        end
      end
    end

    redirect_to project_asphalt_lot_path(@project, @asphalt_lot), notice: "Sublots and lanes created successfully"
  rescue ActiveRecord::RecordInvalid => e
    flash[:alert] = "Error: #{e.message}"
    redirect_to new_project_asphalt_lot_bulk_setup_path(@project, @asphalt_lot)
  end

  private

  def set_project_and_lot
    @project = Project.find(params[:project_id])
    @asphalt_lot = @project.asphalt_lots.find(params[:asphalt_lot_id])
  end
end
