class ApprovedEquipment < ApplicationRecord
  belongs_to :project
  
  CATEGORIES = [
    "General Equipment",
    "Excavation and Embankment",
    "Asphalt Paving",
    "Specialty"
  ].freeze
  
  validates :name, presence: true
  validates :category, inclusion: { in: CATEGORIES, allow_blank: true }
  
  # Default to General Equipment if category is blank
  before_validation :set_default_category, on: :create
  
  private
  
  def set_default_category
    self.category ||= "General Equipment"
  end
end
