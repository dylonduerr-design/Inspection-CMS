require "csv"

class CoreGenerationsController < ApplicationController
  before_action :set_project_and_lot

  def new
    @core_generation = @asphalt_lot.core_generations.build
  end

  def create
    @core_generation = @asphalt_lot.core_generations.build(core_generation_params)

    if @core_generation.save
      begin
        latest = latest_generation(exclude_id: @core_generation.id)
        locked_ids = @asphalt_lot.asphalt_sublots.where(locked_for_core_generation: true).pluck(:id)

        CoreGenerator.new(@core_generation, locked_sublot_ids: locked_ids).generate!

        if latest && locked_ids.any?
          copy_core_locations(latest, @core_generation, locked_ids)
        end
        respond_to do |format|
          format.html do
            redirect_to project_asphalt_lot_core_generation_path(@project, @asphalt_lot, @core_generation),
                        notice: "Core locations generated successfully"
          end
          format.json do
            render json: {
              message: "Core locations generated successfully",
              generation: generation_payload(@core_generation)
            }, status: :created
          end
        end
      rescue StandardError => e
        @core_generation.destroy
        respond_to do |format|
          format.html do
            flash.now[:alert] = "Generation failed: #{e.message}"
            render :new, status: :unprocessable_entity
          end
          format.json do
            render json: { errors: ["Generation failed: #{e.message}"] }, status: :unprocessable_entity
          end
        end
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @core_generation.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def create_for_sublot
    @sublot = @asphalt_lot.asphalt_sublots.find(params[:sublot_id])

    if @sublot.locked_for_core_generation
      respond_to do |format|
        format.html do
          redirect_back fallback_location: project_asphalt_lot_path(@project, @asphalt_lot),
                        alert: "Sublot #{@sublot.position} is locked and cannot be regenerated"
        end
        format.json do
          render json: { errors: ["Sublot #{@sublot.position} is locked and cannot be regenerated"] }, status: :unprocessable_entity
        end
      end
      return
    end

    @core_generation = @asphalt_lot.core_generations.build(generation_defaults_from_latest)

    if @core_generation.save
      begin
        latest = latest_generation(exclude_id: @core_generation.id)
        CoreGenerator.new(@core_generation, target_sublot_ids: [@sublot.id]).generate!

        if latest
          other_ids = @asphalt_lot.asphalt_sublots.where.not(id: @sublot.id).pluck(:id)
          copy_core_locations(latest, @core_generation, other_ids) if other_ids.any?
        end

        respond_to do |format|
          format.html do
            redirect_to project_asphalt_lot_core_generation_path(@project, @asphalt_lot, @core_generation),
                        notice: "Core locations generated for Sublot #{@sublot.position}"
          end
          format.json do
            render json: {
              message: "Core locations generated for Sublot #{@sublot.position}",
              generation: generation_payload(@core_generation)
            }, status: :created
          end
        end
      rescue StandardError => e
        @core_generation.destroy
        respond_to do |format|
          format.html do
            flash[:alert] = "Generation failed: #{e.message}"
            redirect_back fallback_location: project_asphalt_lot_path(@project, @asphalt_lot)
          end
          format.json do
            render json: { errors: ["Generation failed: #{e.message}"] }, status: :unprocessable_entity
          end
        end
      end
    else
      respond_to do |format|
        format.html do
          redirect_back fallback_location: project_asphalt_lot_path(@project, @asphalt_lot),
                        alert: @core_generation.errors.full_messages.to_sentence
        end
        format.json do
          render json: { errors: @core_generation.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end

  def show
    @core_generation = @asphalt_lot.core_generations
                         .includes(core_locations: [:asphalt_lane, :asphalt_sublot, :left_lane, :right_lane])
                         .find(params[:id])
    @sort_by_sublot = params[:sort] == "sublot"

    @core_locations = if @sort_by_sublot
      @core_generation.core_locations.order(:asphalt_sublot_id, :core_type, :mark)
    else
      @core_generation.core_locations.order(:core_type, :asphalt_sublot_id, :mark)
    end
  end

  def export_csv
    @core_generation = @asphalt_lot.core_generations
                         .includes(core_locations: [:asphalt_lane, :asphalt_sublot])
                         .find(params[:id])

    csv = CSV.generate do |out|
      out << ["Mark", "Type", "Sublot", "Lane", "Lot Dist (ft)", "Sublot Linear (ft)", "Station in Lane (ft)", "Offset in Lane (ft)"]
      @core_generation.core_locations.order(:mark).find_each do |loc|
        out << [
          loc.mark, loc.core_type, loc.asphalt_sublot&.position, loc.lane_index,
          loc.distance_from_lot_start_ft, loc.linear_in_sublot_ft,
          loc.station_in_lane_ft, loc.offset_in_lane_ft
        ]
      end
    end

    send_data csv,
              filename: "lot-#{@asphalt_lot.lot_number}-core-locations-#{@core_generation.id}.csv",
              type: "text/csv"
  end

  def export_xlsx
    @core_generation = @asphalt_lot.core_generations.find(params[:id])
    result = CoreLocationXlsxExporter.new(@core_generation, @asphalt_lot).to_stream

    send_data result[:stream].read,
              filename: result[:filename],
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  private

  def set_project_and_lot
    @project = Project.find(params[:project_id])
    @asphalt_lot = @project.asphalt_lots.find(params[:asphalt_lot_id])
  end

  def core_generation_params
    params.fetch(:core_generation, ActionController::Parameters.new).permit(
      :seed, :rounding_increment_ft, :mat_edge_buffer_ft,
      :lane_start_buffer_ft, :mat_cores_per_sublot, :joint_cores_per_joint
    )
  end

  def generation_payload(generation)
    locations = generation.core_locations.includes(:asphalt_sublot, :asphalt_lane).order(:mark).map do |loc|
      {
        mark: loc.mark,
        core_type: loc.mat? ? "Mat" : "Joint",
        sublot: loc.asphalt_sublot&.position,
        lane: loc.lane_index,
        station_ft: loc.station_in_lane_ft&.to_f&.round(1),
        offset_ft: loc.offset_in_lane_ft&.to_f&.round(1)
      }
    end

    {
      id: generation.id,
      seed: generation.seed,
      created_at: generation.created_at.strftime("%b %d, %Y %H:%M"),
      location_count: locations.size,
      locations: locations
    }
  end

  def latest_generation(exclude_id: nil)
    scope = @asphalt_lot.core_generations.order(created_at: :desc)
    scope = scope.where.not(id: exclude_id) if exclude_id
    scope.first
  end

  def generation_defaults_from_latest
    latest = latest_generation
    return {} unless latest

    {
      rounding_increment_ft: latest.rounding_increment_ft,
      mat_edge_buffer_ft: latest.mat_edge_buffer_ft,
      lane_start_buffer_ft: latest.lane_start_buffer_ft,
      mat_cores_per_sublot: latest.mat_cores_per_sublot,
      joint_cores_per_joint: latest.joint_cores_per_joint
    }
  end

  def copy_core_locations(from_generation, to_generation, sublot_ids)
    return if from_generation.nil? || sublot_ids.empty?

    from_generation.core_locations.where(asphalt_sublot_id: sublot_ids).find_each do |loc|
      CoreLocation.create!(
        core_generation: to_generation,
        asphalt_lot: loc.asphalt_lot,
        asphalt_sublot: loc.asphalt_sublot,
        asphalt_lane: loc.asphalt_lane,
        left_lane: loc.left_lane,
        right_lane: loc.right_lane,
        core_type: loc.core_type,
        lane_index: loc.lane_index,
        linear_in_sublot_ft: loc.linear_in_sublot_ft,
        station_in_lane_ft: loc.station_in_lane_ft,
        offset_in_lane_ft: loc.offset_in_lane_ft,
        distance_from_lot_start_ft: loc.distance_from_lot_start_ft,
        mark: loc.mark,
        station_random_number: loc.station_random_number,
        offset_random_number: loc.offset_random_number
      )
    end
  end
end
