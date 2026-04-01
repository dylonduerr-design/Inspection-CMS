class AddSovCategoryAndTradePackageToBidItems < ActiveRecord::Migration[7.1]
  def change
    add_column :bid_items, :sov_category, :string
    add_column :bid_items, :trade_package, :string
    add_index :bid_items, :sov_category
    add_index :bid_items, :trade_package
  end
end
