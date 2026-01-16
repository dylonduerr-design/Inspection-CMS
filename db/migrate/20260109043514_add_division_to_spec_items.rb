class AddDivisionToSpecItems < ActiveRecord::Migration[7.1]
  def change
    add_column :spec_items, :division, :string
  end
end
