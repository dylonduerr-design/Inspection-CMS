class AddCoreLockModeToAsphaltSublots < ActiveRecord::Migration[7.1]
  def up
    add_column :asphalt_sublots, :core_lock_mode, :integer, default: 0, null: false

    # Backfill from existing boolean
    execute <<~SQL
      UPDATE asphalt_sublots
      SET core_lock_mode = CASE WHEN locked_for_core_generation = true THEN 3 ELSE 0 END
    SQL
  end

  def down
    remove_column :asphalt_sublots, :core_lock_mode
  end
end
