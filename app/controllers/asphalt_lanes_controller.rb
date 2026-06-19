class AsphaltLanesController < ApplicationController
  before_action :set_project_lot_and_sublot
  before_action :set_lane, only: %i[update destroy]

  def create
    next_position = @sublot.asphalt_lanes.maximum(:position).to_i + 1
    @lane = @sublot.asphalt_lanes.build(lane_params.merge(position: next_position))

    if @lane.save
      respond_to do |format|
        format.html { redirect_to project_asphalt_lot_path(@project, @asphalt_lot), notice: "Lane #{@lane.position} added." }
        format.json { render json: { lane: lane_payload(@lane) }, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to project_asphalt_lot_path(@project, @asphalt_lot), alert: @lane.errors.full_messages.to_sentence }
        format.json { render json: { errors: @lane.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @lane.update(lane_params)
      respond_to do |format|
        format.html { redirect_to project_asphalt_lot_path(@project, @asphalt_lot), notice: "Lane #{@lane.position} updated.", status: :see_other }
        format.json { render json: { lane: lane_payload(@lane) }, status: :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_to project_asphalt_lot_path(@project, @asphalt_lot), alert: @lane.errors.full_messages.to_sentence }
        format.json { render json: { errors: @lane.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    position = @lane.position
    @lane.destroy!

    respond_to do |format|
      format.html { redirect_to project_asphalt_lot_path(@project, @asphalt_lot), notice: "Lane #{position} deleted.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def set_project_lot_and_sublot
    @project = Project.find(params[:project_id])
    @asphalt_lot = @project.asphalt_lots.find(params[:asphalt_lot_id])
    @sublot = @asphalt_lot.asphalt_sublots.find(params[:asphalt_sublot_id])
  end

  def set_lane
    @lane = @sublot.asphalt_lanes.find(params[:id])
  end

  def lane_params
    params.require(:asphalt_lane).permit(:length_ft, :width_ft)
  end

  def lane_payload(lane)
    {
      id: lane.id,
      position: lane.position,
      length_ft: lane.length_ft.to_f,
      width_ft: lane.width_ft.to_f,
      asphalt_sublot_id: lane.asphalt_sublot_id
    }
  end
end
