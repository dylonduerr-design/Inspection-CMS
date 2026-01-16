class AddLocationToPlacedQuantities < ActiveRecord::Migration[7.1]
  def change
    add_column :placed_quantities, :location, :string
  end
end