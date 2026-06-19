class CreateAstmRandomNumbers < ActiveRecord::Migration[7.1]
  def change
    create_table :astm_random_numbers do |t|
      t.integer :row, null: false
      t.integer :column, null: false
      t.decimal :value, precision: 10, scale: 4, null: false

      t.timestamps
    end

    add_index :astm_random_numbers, [:row, :column], unique: true
  end
end
