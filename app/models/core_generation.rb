class CoreGeneration < ApplicationRecord
  belongs_to :asphalt_lot, touch: true

  has_many :report_core_generations, dependent: :destroy
  has_many :reports, through: :report_core_generations
  has_many :core_locations, dependent: :destroy

  before_validation :ensure_seed

  validates :rounding_increment_ft, presence: true, numericality: { greater_than: 0 }
  validates :mat_edge_buffer_ft, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :lane_start_buffer_ft, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :mat_cores_per_sublot, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :joint_cores_per_joint, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  private

  def ensure_seed
    self.seed = SecureRandom.random_number(2**31).to_s if seed.blank?
  end
end
