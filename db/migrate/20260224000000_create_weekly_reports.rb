class CreateWeeklyReports < ActiveRecord::Migration[7.1]
  def change
    create_table :weekly_reports do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.date :start_date, null: false
      t.date :end_date, null: false
      t.integer :report_number
      t.integer :status, default: 0, null: false

      # Section 2 — Weather
      t.text :weather_summary
      t.jsonb :weather_data_json, default: {}

      # Section 3 — Completion
      t.jsonb :completion_data_json, default: {}

      # Section 4 — Work Summary
      t.text :work_summary

      # Section 5a — Lab/Field Testing
      t.text :lab_testing_summary

      # Section 5b — Materials
      t.text :materials_summary

      # Section 7 — Problem Areas
      t.text :problem_areas

      # AI generation tracking
      t.string :ai_status, default: 'idle'
      t.text :ai_error

      t.timestamps
    end

    add_index :weekly_reports, [:project_id, :end_date], unique: true
    add_index :weekly_reports, [:project_id, :report_number], unique: true
  end
end
