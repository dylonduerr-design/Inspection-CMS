class ScopeAsphaltLotUniquenessToPlantAndMix < ActiveRecord::Migration[7.1]
  def change
    remove_index :asphalt_lots,
                 name: "index_asphalt_lots_on_project_plant_lot_number"

    add_index :asphalt_lots,
              [:project_id, :plant, :mix_type, :lot_number],
              unique: true,
              name: "index_asphalt_lots_on_project_plant_mix_lot_number"
  end
end
