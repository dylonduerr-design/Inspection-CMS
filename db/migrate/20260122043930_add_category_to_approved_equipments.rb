class AddCategoryToApprovedEquipments < ActiveRecord::Migration[7.1]
  def change
    add_column :approved_equipments, :category, :string
  end
end
