class AddContractDayToReports < ActiveRecord::Migration[7.1]
  def change
    add_column :reports, :contract_day, :integer
  end
end
