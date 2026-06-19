# frozen_string_literal: true

class AddAiStageToReports < ActiveRecord::Migration[7.1]
  def change
    add_column :reports, :ai_stage, :string
  end
end
