class CreateImportedReports < ActiveRecord::Migration[7.1]
  def change
    create_table :imported_reports do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: true, foreign_key: true

      t.string :status, null: false, default: "imported"

      # Extracted/parsed metadata (best-effort)
      t.string :contract_number
      t.string :project_title
      t.float :template_confidence
      t.text :template_errors

      # Parsed content (store raw extraction for now; we can map later)
      t.jsonb :parsed_data

      t.timestamps
    end

    add_index :imported_reports, :contract_number
    add_index :imported_reports, :status
  end
end
