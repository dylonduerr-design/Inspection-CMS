# db/migrate/[TIMESTAMP]_make_report_fields_optional.rb
class MakeReportFieldsOptional < ActiveRecord::Migration[7.1]
  def change
    # Allow these to be null for the "Draft" state
    change_column_null :reports, :project_id, true
    change_column_null :reports, :phase_id, true
  end
end