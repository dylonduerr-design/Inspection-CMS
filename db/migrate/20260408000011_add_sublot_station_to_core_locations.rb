class AddSublotStationToCoreLocations < ActiveRecord::Migration[7.1]
  def change
    add_column :core_locations, :sublot_station_ft, :decimal, precision: 12, scale: 2
    add_column :core_locations, :station_adjusted, :boolean, default: false, null: false
  end
end
