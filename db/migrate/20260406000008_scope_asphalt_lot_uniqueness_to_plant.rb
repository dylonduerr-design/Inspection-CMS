class ScopeAsphaltLotUniquenessToPlant < ActiveRecord::Migration[7.1]
  def change
    remove_index :asphalt_lots, [:project_id, :lot_number],
                 name: "index_asphalt_lots_on_project_id_and_lot_number"

    add_index :asphalt_lots, [:project_id, :plant, :lot_number],
              unique: true,
              name: "index_asphalt_lots_on_project_plant_lot_number"
  end
end
