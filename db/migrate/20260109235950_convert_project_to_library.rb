class ConvertProjectToLibrary < ActiveRecord::Migration[7.1]
  def change
    # 1. Add the "Header" fields to the Project Library
    add_column :projects, :contract_number, :string
    add_column :projects, :project_manager, :string
    add_column :projects, :construction_manager, :string
    add_column :projects, :contract_days, :integer
    add_column :projects, :contract_start_date, :date

    # 2. Link Bid Items to Projects
    # We allow null temporarily (null: true) to avoid crashing existing data
    add_reference :bid_items, :project, null: true, foreign_key: true
  end
end