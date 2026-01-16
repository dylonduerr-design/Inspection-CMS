class EquipmentEntry < ApplicationRecord
  belongs_to :report

  # Optional: Validations
  validates :contractor, presence: true
  validates :make_model, presence: true
end