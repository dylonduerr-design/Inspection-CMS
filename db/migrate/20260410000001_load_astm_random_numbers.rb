require "csv"

class LoadAstmRandomNumbers < ActiveRecord::Migration[7.1]
  # Inline model so this migration is insulated from future changes to
  # app/models/astm_random_number.rb.
  class AstmRandomNumber < ActiveRecord::Base
    self.table_name = "astm_random_numbers"
  end

  def up
    csv_path = Rails.root.join("db", "astm_d3665_random_numbers.csv")

    unless File.exist?(csv_path)
      raise "ASTM D3665 CSV not found at #{csv_path}. This file must ship with the app."
    end

    now = Time.current
    records = []

    CSV.foreach(csv_path, headers: true) do |row|
      row_number = row["Row"].to_i
      (1..20).each do |col|
        value = row[col.to_s]
        next if value.blank?

        records << {
          row: row_number,
          column: col,
          value: value.to_d,
          created_at: now,
          updated_at: now
        }
      end
    end

    # Idempotent: the [:row, :column] unique index backs the upsert, so this
    # migration is safe to re-run and safe on environments where the rake
    # task already populated the table.
    AstmRandomNumber.upsert_all(records, unique_by: [:row, :column]) if records.any?

    say "Loaded #{records.size} ASTM D3665 random number entries."
  end

  def down
    # Reference data required by CoreGenerator — there is no meaningful
    # rollback. Leaving rows in place is safer than emptying the table.
  end
end
