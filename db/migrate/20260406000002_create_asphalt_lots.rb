class CreateAsphaltLots < ActiveRecord::Migration[7.1]
  def change
    create_table :asphalt_lots do |t|
      t.references :project, null: false, foreign_key: true
      t.string :lot_number, null: false
      t.string :plant
      t.string :mix_type
      t.string :contractor
      t.string :mix_design
      t.string :pg
      t.text :description
      t.date :paving_date

      t.timestamps
    end

    add_index :asphalt_lots, [:project_id, :lot_number], unique: true
  end
end
