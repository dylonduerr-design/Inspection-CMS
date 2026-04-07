class CreateCoreGenerations < ActiveRecord::Migration[7.1]
  def change
    create_table :core_generations do |t|
      t.references :asphalt_lot, null: false, foreign_key: true
      t.references :report, null: true, foreign_key: true
      t.string :seed
      t.decimal :rounding_increment_ft, precision: 10, scale: 2, default: 0.5
      t.decimal :mat_edge_buffer_ft, precision: 10, scale: 2, default: 1.0
      t.decimal :lane_start_buffer_ft, precision: 10, scale: 2, default: 10.0
      t.integer :mat_cores_per_sublot, default: 1
      t.integer :joint_cores_per_joint, default: 1

      t.timestamps
    end
  end
end
