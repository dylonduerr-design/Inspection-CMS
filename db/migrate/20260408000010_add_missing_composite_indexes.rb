class AddMissingCompositeIndexes < ActiveRecord::Migration[7.1]
  def change
    add_index :reports, [:project_id, :status, :start_date],
              name: "index_reports_on_project_status_start_date",
              if_not_exists: true

    add_index :reports, [:user_id, :status],
              name: "index_reports_on_user_id_and_status",
              if_not_exists: true

    add_index :placed_quantities, [:report_id, :bid_item_id],
              name: "index_placed_quantities_on_report_and_bid_item",
              if_not_exists: true

    add_index :core_locations, [:core_generation_id, :asphalt_sublot_id],
              name: "index_core_locations_on_generation_and_sublot",
              if_not_exists: true
  end
end
