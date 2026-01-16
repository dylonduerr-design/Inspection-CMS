class AddFieldsToReports < ActiveRecord::Migration[7.1]
  def change
    # --- 1. Weather Enhancements ---
    # Visibility tracks per shift (Start/Mid/End)
    add_column :reports, :visibility_1, :string
    add_column :reports, :visibility_2, :string
    add_column :reports, :visibility_3, :string
    
    # Surface Conditions is now a SINGLE site-wide field
    add_column :reports, :surface_conditions, :string

    # --- 2. New Compliance Item ---
    # 0=N/A, 1=Yes (Compliant), 2=No (Non-Compliant)
    add_column :reports, :phasing_compliance, :integer, default: 0

    # --- 3. Conditional Notes for Compliance ---
    # Stores the explanation when "No" is selected
    add_column :reports, :phasing_compliance_note, :text
    add_column :reports, :traffic_control_note, :text
    add_column :reports, :environmental_note, :text
    add_column :reports, :security_note, :text
    add_column :reports, :air_ops_note, :text
    add_column :reports, :swppp_note, :text
  end
end