# frozen_string_literal: true

# Service to generate random mat and joint core locations for a lot.
# Uses ASTM D3665 random number tables for core location selection.
# Generates configured mat and joint core counts per sublot.
class CoreGenerator
  attr_reader :lot, :generation, :target_sublot_ids, :locked_sublot_ids

  def initialize(core_generation, target_sublot_ids: nil, locked_sublot_ids: nil)
    @generation = core_generation
    @lot = core_generation.asphalt_lot
    @target_sublot_ids = Array(target_sublot_ids).presence
    @locked_sublot_ids = Array(locked_sublot_ids).presence || []
    @random_index = 0
  end

  def generate!
    validate_astm_random_table!

    CoreLocation.transaction do
      lot_linear_offset = 0.0

      scope = lot.asphalt_sublots.includes(:asphalt_lanes).order(:position)
      scope = scope.where(id: target_sublot_ids) if target_sublot_ids

      scope.each do |sublot|
        next if locked_sublot_ids.include?(sublot.id)

        sublot_linear_total = sublot.asphalt_lanes.sum(&:length_ft)

        # Generate configured mat core count for this sublot.
        generation.mat_cores_per_sublot.to_i.times do |index|
          create_mat_core(
            sublot,
            lot_linear_offset,
            sequence_index: index + 1,
            sequence_total: generation.mat_cores_per_sublot.to_i
          )
        end

        # Generate configured joint core count using a selected adjacent lane pair.
        lanes = sublot.asphalt_lanes.order(:position).to_a
        joint_segment = pick_joint_segment(lanes)
        if joint_segment && generation.joint_cores_per_joint.to_i.positive?
          generation.joint_cores_per_joint.to_i.times do |index|
            create_joint_core(
              sublot,
              joint_segment[:left],
              joint_segment[:right],
              lot_linear_offset,
              sequence_index: index + 1,
              sequence_total: generation.joint_cores_per_joint.to_i
            )
          end
        end

        lot_linear_offset += sublot_linear_total
      end
    end

    generation
  end

  private

  def create_mat_core(sublot, lot_linear_offset, sequence_index:, sequence_total:)
    # Pick a lane weighted by length using ASTM random number
    lane = pick_lane_by_length(sublot.asphalt_lanes.to_a)
    return unless lane

    # Compute valid station range (with start buffer)
    min_station = generation.lane_start_buffer_ft
    max_station = lane.length_ft
    return if min_station >= max_station

    # Sample station using ASTM random number
    station, station_random = sample_using_astm_random(min_station, max_station)

    # Compute valid offset range (with edge buffers)
    min_offset = generation.mat_edge_buffer_ft
    max_offset = lane.width_ft - generation.mat_edge_buffer_ft
    return if min_offset >= max_offset

    # Sample offset using ASTM random number
    offset, offset_random = sample_using_astm_random(min_offset, max_offset)

    # Compute lane-linear distance within sublot
    lanes_before = sublot.asphalt_lanes.where("position < ?", lane.position)
    linear_in_sublot = lanes_before.sum(&:length_ft) + station

    # Compute distance from lot start
    distance_from_lot_start = lot_linear_offset + linear_in_sublot

    # Generate mark
    mark = mark_for("M", sublot.position, sequence_index, sequence_total)

    CoreLocation.create!(
      core_generation: generation,
      asphalt_lot: lot,
      asphalt_sublot: sublot,
      asphalt_lane: lane,
      core_type: :mat,
      lane_index: lane.position,
      linear_in_sublot_ft: linear_in_sublot,
      station_in_lane_ft: station,
      offset_in_lane_ft: offset,
      distance_from_lot_start_ft: distance_from_lot_start,
      mark: mark,
      station_random_number: station_random,
      offset_random_number: offset_random
    )
  end

  def create_joint_core(sublot, left_lane, right_lane, lot_linear_offset, sequence_index:, sequence_total:)
    # Joint length is the overlap of the two lanes
    joint_length = [left_lane.length_ft, right_lane.length_ft].min

    # Compute valid station range (with start buffer)
    min_station = generation.lane_start_buffer_ft
    max_station = joint_length
    return if min_station >= max_station

    # Sample station using ASTM random number
    station, station_random = sample_using_astm_random(min_station, max_station)

    # For joints, offset is at the boundary between lanes (no random number needed)
    offset = left_lane.width_ft
    offset_random = nil

    # Compute lane-linear distance within sublot (use left lane as reference)
    lanes_before = sublot.asphalt_lanes.where("position < ?", left_lane.position)
    linear_in_sublot = lanes_before.sum(&:length_ft) + station

    # Compute distance from lot start
    distance_from_lot_start = lot_linear_offset + linear_in_sublot

    # Generate mark
    mark = mark_for("J", sublot.position, sequence_index, sequence_total)

    CoreLocation.create!(
      core_generation: generation,
      asphalt_lot: lot,
      asphalt_sublot: sublot,
      asphalt_lane: left_lane,
      left_lane: left_lane,
      right_lane: right_lane,
      core_type: :joint,
      lane_index: left_lane.position,
      linear_in_sublot_ft: linear_in_sublot,
      station_in_lane_ft: station,
      offset_in_lane_ft: offset,
      distance_from_lot_start_ft: distance_from_lot_start,
      mark: mark,
      station_random_number: station_random,
      offset_random_number: offset_random
    )
  end

  def pick_lane_by_length(lanes)
    return nil if lanes.empty?

    total_length = lanes.sum(&:length_ft)
    random_value = get_next_astm_random
    target = random_value * total_length

    cumulative = 0.0
    lanes.each do |lane|
      cumulative += lane.length_ft
      return lane if cumulative >= target
    end

    lanes.last
  end

  def sample_using_astm_random(min_val, max_val)
    # Get ASTM random number (0 to 1)
    random_value = get_next_astm_random

    # Map to range and round to grid
    increment = generation.rounding_increment_ft
    value = min_val + random_value * (max_val - min_val)

    # Round to nearest increment and return both the value and the random number used
    [((value / increment).round * increment).round(2), random_value]
  end

  def pick_joint_segment(lanes)
    return nil if lanes.size < 2

    segments = lanes.each_cons(2).map do |left, right|
      overlap = [left.length_ft, right.length_ft].min
      { left:, right:, length: overlap.to_f }
    end.select { |seg| seg[:length] > 0 }

    return nil if segments.empty?

    total = segments.sum { |seg| seg[:length] }
    target = get_next_astm_random * total

    cumulative = 0.0
    segments.each do |seg|
      cumulative += seg[:length]
      return seg if cumulative >= target
    end

    segments.last
  end

  def get_next_astm_random
    # Use the seed to determine starting position in ASTM table
    start_row = (generation.seed.to_i % astm_row_count) + 1
    start_col = ((generation.seed.to_i / astm_row_count) % astm_column_count) + 1

    # Calculate current position
    total_offset = start_col - 1 + (start_row - 1) * astm_column_count + @random_index
    row = (total_offset / astm_column_count) % astm_row_count + 1
    col = (total_offset % astm_column_count) + 1

    @random_index += 1

    # Get random number from ASTM table
    astm_number = AstmRandomNumber.find_by(row: row, column: col)

    unless astm_number
      raise "ASTM random number table is missing row=#{row}, column=#{col}. Run rake astm:load_random_numbers and retry."
    end

    astm_number.value.to_f
  end

  def astm_row_count
    @astm_row_count ||= AstmRandomNumber.maximum(:row).to_i
  end

  def astm_column_count
    20
  end

  def validate_astm_random_table!
    rows = astm_row_count
    raise "ASTM random number table is empty. Run rake astm:load_random_numbers and retry." if rows <= 0

    expected_cells = rows * astm_column_count
    actual_cells = AstmRandomNumber.count

    if actual_cells < expected_cells
      raise "ASTM random number table is incomplete (#{actual_cells}/#{expected_cells} cells). Run rake astm:load_random_numbers and retry."
    end
  end

  def mark_for(prefix, sublot_position, sequence_index, sequence_total)
    base = "#{prefix} #{lot.lot_number}-#{sublot_position}"
    sequence_total > 1 ? "#{base}-#{sequence_index}" : base
  end
end
