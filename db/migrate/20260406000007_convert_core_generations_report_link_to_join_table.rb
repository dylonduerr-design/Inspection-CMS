class ConvertCoreGenerationsReportLinkToJoinTable < ActiveRecord::Migration[7.1]
  class MigrationCoreGeneration < ApplicationRecord
    self.table_name = "core_generations"
  end

  class MigrationReportCoreGeneration < ApplicationRecord
    self.table_name = "report_core_generations"
  end

  def up
    create_table :report_core_generations do |t|
      t.references :report, null: false, foreign_key: true
      t.references :core_generation, null: false, foreign_key: true
      t.timestamps
    end

    add_index :report_core_generations, [:report_id, :core_generation_id], unique: true, name: "index_report_core_generations_unique"

    MigrationCoreGeneration.reset_column_information
    MigrationReportCoreGeneration.reset_column_information

    MigrationCoreGeneration.where.not(report_id: nil).find_each do |generation|
      MigrationReportCoreGeneration.find_or_create_by!(
        report_id: generation.report_id,
        core_generation_id: generation.id
      )
    end

    remove_reference :core_generations, :report, foreign_key: true, index: true
  end

  def down
    add_reference :core_generations, :report, foreign_key: true, index: true

    MigrationCoreGeneration.reset_column_information
    MigrationReportCoreGeneration.reset_column_information

    MigrationReportCoreGeneration.select(:core_generation_id, :report_id).find_each do |link|
      MigrationCoreGeneration.where(id: link.core_generation_id, report_id: nil).update_all(report_id: link.report_id)
    end

    remove_index :report_core_generations, name: "index_report_core_generations_unique"
    drop_table :report_core_generations
  end
end
