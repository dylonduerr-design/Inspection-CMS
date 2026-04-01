class AddAuthorizedByToReports < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:reports, :authorized_by_id)
      add_reference :reports, :authorized_by, foreign_key: { to_table: :users }, null: true
    end
  end
end
