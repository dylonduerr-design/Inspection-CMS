class AddBidQuantityToBidItems < ActiveRecord::Migration[7.0]
  def change
    add_column :bid_items, :bid_quantity, :decimal, precision: 15, scale: 3
  end
end
