class AddChangeOrderToPlacedQuantities < ActiveRecord::Migration[7.1]
  def change
    add_reference :placed_quantities, :change_order, null: true, foreign_key: true
  end
end
