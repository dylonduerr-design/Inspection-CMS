class CreateAsphaltSublots < ActiveRecord::Migration[7.1]
  def change
    create_table :asphalt_sublots do |t|
      t.references :asphalt_lot, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :name
      t.boolean :locked_for_core_generation, default: false

      t.timestamps
    end

    add_index :asphalt_sublots, [:asphalt_lot_id, :position], unique: true
  end
end
