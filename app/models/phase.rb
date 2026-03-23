class Phase < ApplicationRecord
  # --- 1. Associations ---
  belongs_to :project
  has_many :reports, dependent: :restrict_with_error
  
  # --- 2. Validations ---
  validates :name, presence: true, uniqueness: { scope: :project_id }
end
