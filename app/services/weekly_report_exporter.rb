require 'json'
require 'tempfile'
require 'open3'

class WeeklyReportExporter
  def self.generate(weekly_report)
    template_path = Rails.root.join('app', 'assets', 'documents', 'FAA_Weekly_Template.docx')

    unless File.exist?(template_path)
      raise "FAA Weekly template not found: Please ensure FAA_Weekly_Template.docx exists in app/assets/documents"
    end

    data_hash = build_data_hash(weekly_report)

    input_file = Tempfile.new(['weekly_report_data', '.json'])
    output_file = Tempfile.new(['weekly_report', '.docx'])

    begin
      input_file.write(data_hash.to_json)
      input_file.flush

      python_script = Rails.root.join('python', 'export_report.py')
      venv_python = Rails.root.join('.venv', 'bin', 'python3')
      python_cmd = File.exist?(venv_python) ? venv_python : 'python3'

      cmd = [
        python_cmd.to_s,
        python_script.to_s,
        '--input', input_file.path,
        '--template', template_path.to_s,
        '--output', output_file.path
      ]

      Rails.logger.info("WeeklyReportExporter: Running command: #{cmd.join(' ')}")

      stdout, stderr, status = Open3.capture3(*cmd)

      unless status.success?
        Rails.logger.error("WeeklyReportExporter: Python script failed")
        Rails.logger.error("STDERR: #{stderr}")
        # Extract the logged ERROR message (e.g. "ERROR: Error generating report: ...");
        # fall back to the last non-empty line if not found.
        error_line = stderr.lines.find { |l| l.strip.start_with?('ERROR:') }&.strip&.sub(/^ERROR:\s*/, '')
        error_line = stderr.strip.lines.last.to_s.strip if error_line.blank?
        raise error_line
      end

      Rails.logger.info("WeeklyReportExporter: FAA Weekly Report generated successfully")
      output_file

    rescue => e
      Rails.logger.error("WeeklyReportExporter: Exception - #{e.message}")
      output_file.close
      output_file.unlink
      raise e
    ensure
      input_file.close
      input_file.unlink
    end
  end

  private

  def self.build_data_hash(wr)
    project = wr.project
    completion = wr.completion_data_json || {}

    categories = (completion["categories"] || []).map do |cat|
      { name: cat["name"], percent: "#{cat['percent']}%" }
    end

    {
      # Header / Project Info
      project_name: project&.name || "",
      contract_number: project&.contract_number || "",
      report_number: wr.report_number.to_s,
      period_start: format_date(wr.start_date),
      period_end: format_date(wr.end_date),
      contractor_name: project&.prime_contractor || "",

      # Section 1 — Contract Time
      contract_time: "#{project&.contract_days} Calendar Days",
      days_charged: wr.days_charged.to_s,
      last_working_day: wr.last_working_day_formatted,

      # Section 2 — Weather
      weather_summary: wr.weather_summary.presence || "",

      # Section 3 — Completion
      overall_completion_pct: "#{completion['overall_percent'] || 0}%",
      categories: categories,
      completion_narrative: wr.completion_narrative.presence || "",

      # Section 4 — Work Summary
      work_summary: wr.work_summary.presence || "",

      # Section 5a — Lab/Field Testing
      lab_testing_summary: wr.lab_testing_summary.presence || "",

      # Section 5b — Materials
      materials_summary: wr.materials_summary.presence || "",

      # Section 7 — Problem Areas
      problem_areas: wr.problem_areas.presence || ""
    }
  end

  def self.format_date(date)
    return "" unless date

    date.strftime("%-m/%-d/%Y")
  end
end
