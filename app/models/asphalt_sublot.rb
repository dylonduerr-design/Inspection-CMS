class AsphaltSublot < ApplicationRecord
  belongs_to :asphalt_lot, touch: true

  has_many :asphalt_lanes, -> { order(:position) }, dependent: :destroy
  has_many :core_locations, dependent: :destroy

  enum :core_lock_mode, { none: 0, mat_only: 1, joint_only: 2, all: 3 }, prefix: :lock

  validates :position, presence: true, numericality: { only_integer: true, greater_than: 0 }

  def mat_locked?
    lock_mat_only? || lock_all?
  end

  def joint_locked?
    lock_joint_only? || lock_all?
  end
end
