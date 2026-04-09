class ChangeOrder < ApplicationRecord
  belongs_to :project
  has_many :placed_quantities, dependent: :restrict_with_error

  validates :number, presence: true,
                     numericality: { only_integer: true, greater_than: 0 },
                     uniqueness: { scope: :project_id, message: "already exists in this project" }
  validates :status, inclusion: { in: %w[active closed] }

  scope :active, -> { where(status: "active") }

  def display_name
    "CO ##{number}"
  end
end
