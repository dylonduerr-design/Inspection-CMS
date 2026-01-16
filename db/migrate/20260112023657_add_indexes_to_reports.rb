class AddIndexesToReports < ActiveRecord::Migration[7.1]
  def change
    # Add indexes for frequently queried columns
    add_index :reports, :status unless index_exists?(:reports, :status)
    add_index :reports, :result unless index_exists?(:reports, :result)
    add_index :reports, :start_date unless index_exists?(:reports, :start_date)
    
    # Add indexes for foreign keys if they don't already exist
    add_index :reports, :user_id unless index_exists?(:reports, :user_id)
    add_index :reports, :project_id unless index_exists?(:reports, :project_id)
    add_index :reports, :phase_id unless index_exists?(:reports, :phase_id)
  end
end
