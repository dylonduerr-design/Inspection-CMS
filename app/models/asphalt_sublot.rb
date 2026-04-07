class AsphaltSublot < ApplicationRecord
  belongs_to :asphalt_lot, touch: true

  has_many :asphalt_lanes, -> { order(:position) }, dependent: :destroy
  has_many :core_locations, dependent: :destroy

  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
