class AddSpecToBidItems < ActiveRecord::Migration[7.1]
  def change
    add_reference :bid_items, :spec_item, null: false, foreign_key: true
  end
end
