class AddRemarksToEquipmentEntries < ActiveRecord::Migration[7.1]
  def change
    add_column :equipment_entries, :remarks, :text
  end
end
