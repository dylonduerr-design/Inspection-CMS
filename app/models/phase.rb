class Phase < ApplicationRecord
  # --- 1. Associations ---
  has_many :reports, dependent: :restrict_with_error
  
  # --- 2. Validations ---
  validates :name, presence: true, uniqueness: true
end
