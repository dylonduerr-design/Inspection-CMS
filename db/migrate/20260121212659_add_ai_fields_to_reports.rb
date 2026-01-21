class AddAiFieldsToReports < ActiveRecord::Migration[7.1]
  def change
    add_column :reports, :ai_work_summary, :text
    add_column :reports, :ai_generated_commentary, :text
    add_column :reports, :ai_status, :string, default: 'idle'
    add_column :reports, :ai_generated_at, :datetime
    add_column :reports, :ai_error, :text
    
    add_index :reports, :ai_status
  end
end
