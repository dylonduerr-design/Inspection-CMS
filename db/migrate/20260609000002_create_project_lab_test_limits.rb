class CreateProjectLabTestLimits < ActiveRecord::Migration[7.1]
  def change
    create_table :project_lab_test_limits do |t|
      t.references :project, null: false, foreign_key: true
      t.string :spec_code, null: false
      t.string :parameter, null: false
      t.decimal :lower_limit, precision: 10, scale: 4
      t.decimal :upper_limit, precision: 10, scale: 4

      t.timestamps
    end

    add_index :project_lab_test_limits,
              [:project_id, :spec_code, :parameter],
              unique: true,
              name: "index_project_lab_test_limits_unique"
  end
end
