class AddAuthorizedDateToReports < ActiveRecord::Migration[7.1]
  def change
    add_column :reports, :authorized_date, :datetime
  end
end
