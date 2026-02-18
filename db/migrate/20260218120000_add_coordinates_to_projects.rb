class AddCoordinatesToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :latitude,  :decimal, precision: 10, scale: 6
    add_column :projects, :longitude, :decimal, precision: 10, scale: 6
  end
end
