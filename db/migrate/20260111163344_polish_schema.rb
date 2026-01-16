class PolishSchema < ActiveRecord::Migration[7.1]
  def change
    # ==========================================
    # 1. CLEAN UP THE PARENT (Reports Table)
    # ==========================================
    # Remove legacy columns. All this data now lives in 'crew_entries'.
    remove_column :reports, :laborer_count, :integer
    remove_column :reports, :operator_count, :integer
    remove_column :reports, :survey_count, :integer
    remove_column :reports, :electrician_count, :integer
    
    # Remove the text fields for names (since we are tracking counts now)
    remove_column :reports, :foreman, :string
    remove_column :reports, :superintendent, :string

    # ==========================================
    # 2. UPDATE THE CHILD (Crew Entries Table)
    # ==========================================
    # Remove the old string columns for names
    remove_column :crew_entries, :foreman, :string
    remove_column :crew_entries, :superintendent, :string

    # Add the new integer columns for counts
    add_column :crew_entries, :foreman_count, :integer, default: 0
    add_column :crew_entries, :superintendent_count, :integer, default: 0

    # ==========================================
    # 3. SAFETY & SPEED (Indexes)
    # ==========================================
    # Prevents duplicate Spec Codes globally
    add_index :spec_items, :code, unique: true

    # Prevents duplicate Bid Items within the SAME Project
    add_index :bid_items, [:project_id, :code], unique: true

    # Speed up dashboard filtering
    add_index :reports, [:project_id, :status]
    add_index :reports, :start_date
  end
end
