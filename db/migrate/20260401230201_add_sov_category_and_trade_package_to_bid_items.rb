class AddSovCategoryAndTradePackageToBidItems < ActiveRecord::Migration[7.1]
  def change
    add_column :bid_items, :sov_category, :string unless column_exists?(:bid_items, :sov_category)
    add_column :bid_items, :trade_package, :string unless column_exists?(:bid_items, :trade_package)
    add_index :bid_items, :sov_category unless index_exists?(:bid_items, :sov_category)
    add_index :bid_items, :trade_package unless index_exists?(:bid_items, :trade_package)
  end
end
