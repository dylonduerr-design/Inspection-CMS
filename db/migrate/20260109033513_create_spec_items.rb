class CreateSpecItems < ActiveRecord::Migration[7.1]
  def change
    create_table :spec_items do |t|
      t.string :code
      t.string :description
      t.jsonb :checklist_questions

      t.timestamps
    end
  end
end
