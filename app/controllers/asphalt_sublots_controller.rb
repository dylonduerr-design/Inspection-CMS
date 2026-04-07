class AsphaltSublotsController < ApplicationController
  before_action :set_project_and_lot
  before_action :set_sublot, only: %i[update destroy toggle_core_lock]

  def create
    attrs = sublot_params.to_h
    attrs["position"] = @asphalt_lot.asphalt_sublots.maximum(:position).to_i + 1 if attrs["position"].blank?
    attrs["name"] = "Sublot #{attrs['position']}" if attrs["name"].blank?

    @sublot = @asphalt_lot.asphalt_sublots.build(attrs)

    if @sublot.save
      respond_to do |format|
        format.html { redirect_to project_asphalt_lot_path(@project, @asphalt_lot), notice: "Sublot created." }
        format.json { render json: { sublot: sublot_payload(@sublot) }, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to project_asphalt_lot_path(@project, @asphalt_lot), alert: @sublot.errors.full_messages.to_sentence }
        format.json { render json: { errors: @sublot.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @sublot.update(sublot_params)
      respond_to do |format|
        format.html { redirect_to project_asphalt_lot_path(@project, @asphalt_lot), notice: "Sublot updated.", status: :see_other }
        format.json { render json: { sublot: sublot_payload(@sublot) }, status: :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_to project_asphalt_lot_path(@project, @asphalt_lot), alert: @sublot.errors.full_messages.to_sentence }
        format.json { render json: { errors: @sublot.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @sublot.destroy!

    respond_to do |format|
      format.html { redirect_to project_asphalt_lot_path(@project, @asphalt_lot), notice: "Sublot deleted.", status: :see_other }
      format.json { head :no_content }
    end
  end

  def toggle_core_lock
    @sublot.update!(locked_for_core_generation: !@sublot.locked_for_core_generation)

    respond_to do |format|
      format.html { redirect_back fallback_location: project_asphalt_lot_path(@project, @asphalt_lot) }
      format.json { render json: { sublot: sublot_payload(@sublot) }, status: :ok }
    end
  end

  private

  def set_project_and_lot
    @project = Project.find(params[:project_id])
    @asphalt_lot = @project.asphalt_lots.find(params[:asphalt_lot_id])
  end

  def set_sublot
    @sublot = @asphalt_lot.asphalt_sublots.find(params[:id])
  end

  def sublot_params
    params.require(:asphalt_sublot).permit(:position, :name)
  end

  def sublot_payload(sublot)
    {
      id: sublot.id,
      position: sublot.position,
      name: sublot.name,
      locked_for_core_generation: sublot.locked_for_core_generation
    }
  end
end
