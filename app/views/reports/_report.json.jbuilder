json.extract! report, :id, :dir_number, :inspection_date, :inspector, :project_id, :phase_id, :status, :result, :created_at, :updated_at
json.url report_url(report, format: :json)
