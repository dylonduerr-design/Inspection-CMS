class AddNotableWeatherEventsToReports < ActiveRecord::Migration[7.1]
  def change
    add_column :reports, :notable_weather_events, :string
  end
end
