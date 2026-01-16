class AddPrimeContractorToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :prime_contractor, :string
  end
end
