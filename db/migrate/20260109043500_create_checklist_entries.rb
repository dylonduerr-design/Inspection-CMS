class CreateChecklistEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :checklist_entries do |t|
      t.references :report, null: false, foreign_key: true
      t.references :spec_item, null: false, foreign_key: true
      t.jsonb :checklist_answers

      t.timestamps
    end
  end
end
