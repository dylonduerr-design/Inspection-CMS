class CreateChangeOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :change_orders do |t|
      t.integer :number, null: false
      t.text :description
      t.string :status, default: "active"
      t.date :approved_date
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end

    add_index :change_orders, [:project_id, :number], unique: true
  end
end
