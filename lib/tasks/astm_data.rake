require "csv"

namespace :astm do
  desc "Load ASTM D3665 random numbers from CSV into astm_random_numbers table (idempotent)"
  task load_random_numbers: :environment do
    csv_path = Rails.root.join("db", "astm_d3665_random_numbers.csv")

    unless File.exist?(csv_path)
      puts "ERROR: CSV not found at #{csv_path}"
      exit 1
    end

    puts "Loading ASTM D3665 random numbers from #{csv_path}..."

    count = 0
    CSV.foreach(csv_path, headers: true) do |row|
      row_number = row["Row"].to_i
      (1..20).each do |col|
        value = row[col.to_s]
        next if value.blank?

        AstmRandomNumber.find_or_create_by!(row: row_number, column: col) do |record|
          record.value = value.to_d
        end
        count += 1
      end
    end

    puts "Done. #{count} entries processed. Total records: #{AstmRandomNumber.count}"
  end
end
