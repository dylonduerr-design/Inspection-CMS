class CreateReportExports < ActiveRecord::Migration[7.1]
  def change
    create_table :report_exports do |t|
      t.references :report, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, default: 'queued', null: false
      t.integer :progress, default: 0, null: false
      t.text :error_message

      t.timestamps
    end
    
    add_index :report_exports, :status
  end
end
