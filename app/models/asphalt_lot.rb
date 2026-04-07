class AsphaltLot < ApplicationRecord
  PLANTS = ['Santa Clara', 'Pleasanton'].freeze
  MIX_TYPES = ['P-401', 'P-403', 'PG 64-10'].freeze

  belongs_to :project

  has_many :asphalt_sublots, -> { order(:position) }, dependent: :destroy
  has_many :asphalt_lanes, through: :asphalt_sublots
  has_many :core_generations, dependent: :destroy

  validates :lot_number, presence: true
  validates :lot_number, uniqueness: { scope: [:project_id, :plant], message: "already exists for this plant" }

  scope :for_plant, ->(plant) { where(plant: plant) if plant.present? }
  scope :for_mix, ->(mix_type) { where(mix_type: mix_type) if mix_type.present? }
end
