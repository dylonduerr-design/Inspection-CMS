class CreateAsphaltLanes < ActiveRecord::Migration[7.1]
  def change
    create_table :asphalt_lanes do |t|
      t.references :asphalt_sublot, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :name
      t.decimal :length_ft, precision: 10, scale: 2, null: false
      t.decimal :width_ft, precision: 10, scale: 2, null: false

      t.timestamps
    end

    add_index :asphalt_lanes, [:asphalt_sublot_id, :position], unique: true
  end
end
