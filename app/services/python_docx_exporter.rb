require 'json'
require 'tempfile'
require 'open3'

class PythonDocxExporter
  PHOTO_SLOT_COUNT = 6
  DEFAULT_ADDITIONAL_ACTIVITIES = "no additional activities to report at this time."
  DEFAULT_ADDITIONAL_INFO = "no additional information to report at this time."

  def self.generate(report)
    # 1. Find template
    template_candidates = [
      Rails.root.join('app', 'assets', 'documents', 'inspection_template.docx')
    ]
    template_path = template_candidates.find { |path| File.exist?(path) }
    
    unless template_path
      Rails.logger.error("PythonDocxExporter: Template not found")
      raise "Template not found: Please ensure inspection_template.docx exists in app/assets/documents"
    end

    # 2. Build JSON payload (track temp files for later cleanup)
    photo_tempfiles = []
    data_hash = build_data_hash(report, photo_tempfiles)
    
    # 3. Create temp files for input/output
    input_file = Tempfile.new(['report_data', '.json'])
    output_file = Tempfile.new(['report', '.docx'])
    
    begin
      # Write JSON data
      input_file.write(data_hash.to_json)
      input_file.flush
      
      # 4. Call Python script
      python_script = Rails.root.join('python', 'export_report.py')
      venv_python = Rails.root.join('.venv', 'bin', 'python3')
      
      # Use venv python if available, otherwise system python3
      python_cmd = File.exist?(venv_python) ? venv_python : 'python3'
      
      cmd = [
        python_cmd.to_s,
        python_script.to_s,
        '--input', input_file.path,
        '--template', template_path.to_s,
        '--output', output_file.path
      ]
      
      Rails.logger.info("PythonDocxExporter: Running command: #{cmd.join(' ')}")
      
      stdout, stderr, status = Open3.capture3(*cmd)
      
      unless status.success?
        Rails.logger.error("PythonDocxExporter: Python script failed")
        Rails.logger.error("STDOUT: #{stdout}")
        Rails.logger.error("STDERR: #{stderr}")
        
        # Raise specific error with stderr content
        raise "Export failed: #{stderr.strip.lines.last.to_s.strip}"
      end
      
      Rails.logger.info("PythonDocxExporter: Report generated successfully")
      Rails.logger.debug("Python output: #{stdout}") if stdout.present?
      
      # Return the tempfile (caller is responsible for closing/unlinking)
      output_file
      
    rescue => e
      Rails.logger.error("PythonDocxExporter: Exception - #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      output_file.close
      output_file.unlink
      raise e # Re-raise to allow caller to handle error
    ensure
      input_file.close
      input_file.unlink
      cleanup_tempfiles(photo_tempfiles)
    end
  end

  private

  def self.build_data_hash(report, photo_tempfiles)
    {
      # General Info
      project: report.project&.name,
      contract_number: report.project&.contract_number.presence || "N/A",
      project_manager: report.project&.project_manager,
      construction_manager: report.project&.construction_manager,
      contractor: report.contractor.presence || report.project&.prime_contractor,
      date: format_date(report.authorized_date),
      start_date: format_date(report.start_date),
      end_date: format_date(report.end_date),
      day_x_of_y: report.contract_day_display,
      start_shift: report.shift_start,
      end_shift: report.shift_end,
      inspector: report.inspector_name,
      authorized_by: report.authorized_by&.email || "",
      authorized_date: format_date(report.authorized_date),

      # Weather (support multiple time periods)
      temp: slash_join(report.temp_1, report.temp_2, report.temp_3),
      weather: slash_join(report.weather_summary_1, report.weather_summary_2, report.weather_summary_3),
      weather_event: slash_join(report.weather_summary_1, report.weather_summary_2, report.weather_summary_3),
      wind: slash_join(report.wind_1, report.wind_2, report.wind_3),
      precip: slash_join(report.precip_1, report.precip_2, report.precip_3),
      vis: slash_join(report.visibility_1, report.visibility_2, report.visibility_3, fallback: "N/A"),
      surface: report.surface_conditions.presence || "N/A",
      notable_weather_events: report.notable_weather_events.presence || "N/A",

      # Compliance & Safety
      sec_status: human_enum(report.security),
      tc_status: human_enum(report.traffic_control),
      air_ops: human_enum(report.air_ops_coordination),
      swppp: human_enum(report.swppp_controls),
      env_status: human_enum(report.environmental),
      phase_status: human_enum(report.phasing_compliance),
      saf_status: human_enum(report.safety_incident),
      saf_description: report.safety_desc || "None",
      def_status: human_enum(report.deficiency_status),
      def_desc: report.deficiency_desc || "None",
      tc_note: report.traffic_control_note.presence || "",
      env_note: report.environmental_note.presence || "",
      sec_note: report.security_note.presence || "",
      air_ops_note: report.air_ops_note.presence || "",
      swppp_note: report.swppp_note.presence || "",
      phase_note: report.phasing_compliance_note.presence || "",

      # Commentary
      commentary: report.commentary,
      add_activity: report.additional_activities.presence || DEFAULT_ADDITIONAL_ACTIVITIES,
      add_info: report.additional_info.presence || DEFAULT_ADDITIONAL_INFO,
      
      # AI-generated content
      ai_work_summary: report.ai_work_summary.presence || "",
      ai_generated_commentary: report.ai_generated_commentary.presence || "",

      # Photos - extract paths and captions
      photos: extract_photos(report, photo_tempfiles),

      # Table data - Placed Quantities
      placed_quantities: report.placed_quantities.map do |pq|
        {
          code: pq.bid_item&.code,
          desc: pq.bid_item&.description,
          qty: pq.quantity,
          notes: pq.notes
        }
      end,

      # Table data - QA Entries
      qa_entries: report.qa_entries.map do |qa|
        {
          code: qa.qa_type,
          test: qa.qa_type,
          location: qa.location,
          result: qa.result,
          remarks: qa.remarks
        }
      end,

      # Table data - Equipment
      equipment_entries: report.equipment_entries.map do |eq|
        {
          contractor: eq.contractor,
          equipment: eq.make_model,
          qty: eq.quantity,
          hours: eq.hours,
          remarks: eq.remarks
        }
      end,

      # Table data - Crew
      crew_entries: report.crew_entries.map do |crew|
        {
          contractor: crew.contractor,
          survey: crew.survey_count,
          super: crew.superintendent_count,
          foreman: crew.foreman_count,
          operator: crew.operator_count,
          laborer: crew.laborer_count,
          electrician: crew.electrician_count,
          remarks: crew.notes
        }
      end
    }
  end

  def self.extract_photos(report, photo_tempfiles)
    # Get first 6 image attachments
    photo_attachments = report.report_attachments
                              .select { |a| image_attachment?(a) }
                              .first(PHOTO_SLOT_COUNT)
    
    photo_attachments.map do |attachment|
      # Download blob to a temp file
      if attachment.file.attached?
        temp_photo = Tempfile.new(['photo', File.extname(attachment.file.filename.to_s)])
        temp_photo.binmode
        temp_photo.write(attachment.file.download)
        temp_photo.flush
        
        photo_tempfiles << temp_photo
        
        {
          path: temp_photo.path,
          caption: attachment.caption || ""
        }
      else
        nil
      end
    end.compact
  end

  def self.cleanup_tempfiles(tempfiles)
    tempfiles.each do |tempfile|
      begin
        tempfile.close
        tempfile.unlink
      rescue => e
        Rails.logger.warn("PythonDocxExporter: Failed to cleanup temp photo #{tempfile.path}: #{e.message}")
      end
    end
  end

  def self.image_attachment?(attachment)
    return false unless attachment.file.attached?
    
    blob = attachment.file.blob
    return false unless blob

    (blob.content_type&.start_with?('image/')) || attachment.file.representable?
  end

  def self.human_enum(val)
    return "N/A" if val.nil?

    str = val.to_s
    return "N/A" if str == "0" || str.end_with?('_na')

    str.include?('_') ? str.split('_').last.capitalize : str.humanize
  end

  def self.format_date(date)
    date&.strftime("%m/%d/%Y")
  end

  def self.slash_join(*values, fallback: "")
    joined = values.compact.reject(&:blank?).join(' / ')
    joined.presence || fallback.to_s
  end
end
