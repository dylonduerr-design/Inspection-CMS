class CoreLocation < ApplicationRecord
  belongs_to :core_generation
  belongs_to :asphalt_lot
  belongs_to :asphalt_sublot
  belongs_to :asphalt_lane

  belongs_to :left_lane, class_name: "AsphaltLane", optional: true, foreign_key: :left_lane_id, inverse_of: :left_lane_core_locations
  belongs_to :right_lane, class_name: "AsphaltLane", optional: true, foreign_key: :right_lane_id, inverse_of: :right_lane_core_locations

  enum :core_type, { mat: 0, joint: 1 }

  validates :core_type, presence: true
  validates :linear_in_sublot_ft, :station_in_lane_ft, :offset_in_lane_ft, :distance_from_lot_start_ft,
            presence: true,
            numericality: true
end
