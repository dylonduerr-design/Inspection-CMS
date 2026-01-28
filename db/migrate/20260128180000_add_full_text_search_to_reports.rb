# Migration to add PostgreSQL full-text search to reports
# This creates a tsvector column with a GIN index and auto-update trigger
class AddFullTextSearchToReports < ActiveRecord::Migration[7.1]
  def up
    # Add tsvector column for full-text search
    add_column :reports, :searchable_tsvector, :tsvector

    # Create GIN index for fast full-text search
    add_index :reports, :searchable_tsvector, using: :gin, name: 'index_reports_on_searchable_tsvector'

    # Create function to update the tsvector column
    execute <<-SQL
      CREATE OR REPLACE FUNCTION reports_search_trigger() RETURNS trigger AS $$
      BEGIN
        NEW.searchable_tsvector :=
          setweight(to_tsvector('english', COALESCE(NEW.commentary, '')), 'A') ||
          setweight(to_tsvector('english', COALESCE(NEW.additional_activities, '')), 'B') ||
          setweight(to_tsvector('english', COALESCE(NEW.additional_info, '')), 'B') ||
          setweight(to_tsvector('english', COALESCE(NEW.deficiency_desc, '')), 'C') ||
          setweight(to_tsvector('english', COALESCE(NEW.safety_desc, '')), 'C') ||
          setweight(to_tsvector('english', COALESCE(NEW.notable_weather_events, '')), 'C');
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;
    SQL

    # Create trigger to auto-update tsvector on insert/update
    execute <<-SQL
      CREATE TRIGGER reports_search_update
      BEFORE INSERT OR UPDATE OF commentary, additional_activities, additional_info, deficiency_desc, safety_desc, notable_weather_events
      ON reports
      FOR EACH ROW
      EXECUTE FUNCTION reports_search_trigger();
    SQL

    # Backfill existing records
    execute <<-SQL
      UPDATE reports SET searchable_tsvector =
        setweight(to_tsvector('english', COALESCE(commentary, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(additional_activities, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(additional_info, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(deficiency_desc, '')), 'C') ||
        setweight(to_tsvector('english', COALESCE(safety_desc, '')), 'C') ||
        setweight(to_tsvector('english', COALESCE(notable_weather_events, '')), 'C');
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS reports_search_update ON reports"
    execute "DROP FUNCTION IF EXISTS reports_search_trigger()"
    remove_index :reports, name: 'index_reports_on_searchable_tsvector'
    remove_column :reports, :searchable_tsvector
  end
end
