class AddResultKindToLabTests < ActiveRecord::Migration[7.1]
  class MigrationLabTestImport < ApplicationRecord
    self.table_name = "lab_test_imports"
  end

  class MigrationLabTestResult < ApplicationRecord
    self.table_name = "lab_test_results"
  end

  def up
    add_column :lab_test_imports, :result_kind, :string
    add_column :lab_test_results, :result_kind, :string

    MigrationLabTestImport.reset_column_information
    MigrationLabTestResult.reset_column_information

    MigrationLabTestResult.find_each do |result|
      result.update_columns(result_kind: inferred_kind(result.spec_code, result.data))
    end

    MigrationLabTestImport.find_each do |import|
      row = Array(import.parsed_data).first
      kind = inferred_kind(import.spec_code, row || {})
      import.update_columns(result_kind: kind) if kind
    end

    change_column_null :lab_test_results, :result_kind, false

    add_index :lab_test_imports, [:project_id, :result_kind]
    add_index :lab_test_results, [:project_id, :result_kind]
    add_index :lab_test_results, [:project_id, :spec_code, :result_kind],
              name: "index_lab_test_results_on_project_spec_kind"
  end

  def down
    remove_index :lab_test_results, name: "index_lab_test_results_on_project_spec_kind"
    remove_index :lab_test_results, [:project_id, :result_kind]
    remove_index :lab_test_imports, [:project_id, :result_kind]
    remove_column :lab_test_results, :result_kind
    remove_column :lab_test_imports, :result_kind
  end

  private

  def inferred_kind(spec_code, data)
    data = data.is_a?(Hash) ? data : {}

    if data.key?("core_id")
      "core_compaction"
    elsif data.key?("air_voids_avg")
      "hma_air_voids"
    elsif spec_code == "P-610"
      "concrete_strength"
    elsif spec_code == "P-403"
      "core_compaction"
    elsif spec_code == "P-401"
      "hma_air_voids"
    end
  end
end
