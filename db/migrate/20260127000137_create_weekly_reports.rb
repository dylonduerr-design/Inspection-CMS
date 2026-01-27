class CreateWeeklyReports < ActiveRecord::Migration[7.1]
  def change
    create_table :weekly_reports do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :start_date
      t.date :end_date
      t.integer :status
      t.text :work_summary
      t.text :anticipated_work
      t.text :deficiencies_summary
      t.json :weather_summary_json
      t.json :lab_summary_json

      t.timestamps
    end
  end
end
