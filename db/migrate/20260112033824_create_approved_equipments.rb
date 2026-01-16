class CreateApprovedEquipments < ActiveRecord::Migration[7.1]
  def change
    create_table :approved_equipments do |t|
      t.string :name
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end
  end
end
