class AddProjectToPhases < ActiveRecord::Migration[7.1]
  def change
    add_reference :phases, :project, null: true, foreign_key: true

    reversible do |dir|
      dir.up do
        # Assign orphaned phases to the first project (if any exist)
        first_project = execute("SELECT id FROM projects ORDER BY created_at ASC LIMIT 1")
        if first_project.any?
          project_id = first_project.first["id"]
          execute("UPDATE phases SET project_id = #{project_id} WHERE project_id IS NULL")
        end
      end
    end

    change_column_null :phases, :project_id, false
  end
end
