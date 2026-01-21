# frozen_string_literal: true

module ReportAi
  class PayloadBuilder
    SCHEMA_VERSION = "report_ai_payload_v1"
    PHOTO_SLOT_COUNT = 6

    def self.build(report)
      new(report).build
    end

    def initialize(report)
      @report = report
    end

    def build
      {
        meta: {
          schema_version: SCHEMA_VERSION,
          generated_at: Time.current.iso8601,
          source: "inspection_cms"
        },
        report: report_summary,
        project: project_summary,
        phase: phase_summary,
        inspector: inspector_summary,
        authorization: authorization_summary,
        weather: weather_summary,
        compliance: compliance_summary,
        narrative: narrative_summary,
        bid_items: bid_items_summary,
        qa_entries: qa_entries_summary,
        workforce: workforce_summary,
        equipment: equipment_summary,
        spec_checklists: spec_checklists_summary,
        attachments: attachments_summary,
        photos: photo_slots
      }
    end

    private

    attr_reader :report

    def report_summary
      {
        id: report.id,
        dir_number: report.dir_number,
        status: report.status,
        result: report.result,
        start_date: format_date(report.start_date),
        end_date: format_date(report.end_date),
        shift_start: report.shift_start,
        shift_end: report.shift_end,
        contract_day: report.contract_day,
        contract_day_display: report.contract_day_display
      }
    end

    def project_summary
      project = report.project
      return {} unless project

      {
        id: project.id,
        name: project.name,
        contract_number: project.contract_number,
        project_manager: project.project_manager,
        construction_manager: project.construction_manager,
        prime_contractor: project.prime_contractor
      }
    end

    def phase_summary
      phase = report.phase
      return {} unless phase

      {
        id: phase.id,
        name: phase.name
      }
    end

    def inspector_summary
      {
        id: report.user_id,
        email: report.user&.email
      }
    end

    def authorization_summary
      {
        authorized_by: report.authorized_by&.email,
        authorized_date: format_date(report.authorized_date)
      }
    end

    def weather_summary
      {
        periods: [
          weather_period("start_of_shift", report.temp_1, report.weather_summary_1, report.wind_1, report.precip_1, report.visibility_1),
          weather_period("mid_shift", report.temp_2, report.weather_summary_2, report.wind_2, report.precip_2, report.visibility_2),
          weather_period("end_of_shift", report.temp_3, report.weather_summary_3, report.wind_3, report.precip_3, report.visibility_3)
        ],
        surface_conditions: report.surface_conditions,
        notable_weather_events: report.notable_weather_events
      }
    end

    def weather_period(label, temp, summary, wind, precip, visibility)
      {
        label: label,
        temp: temp,
        weather_summary: summary,
        wind: wind,
        precip: precip,
        visibility: visibility
      }
    end

    def compliance_summary
      {
        traffic_control: report.traffic_control,
        environmental: report.environmental,
        security: report.security,
        air_ops_coordination: report.air_ops_coordination,
        swppp_controls: report.swppp_controls,
        phasing_compliance: report.phasing_compliance,
        safety_incident: report.safety_incident,
        safety_desc: report.safety_desc,
        deficiency_status: report.deficiency_status,
        deficiency_desc: report.deficiency_desc,
        notes: {
          traffic_control_note: report.traffic_control_note,
          environmental_note: report.environmental_note,
          security_note: report.security_note,
          air_ops_note: report.air_ops_note,
          swppp_note: report.swppp_note,
          phase_note: report.phasing_compliance_note
        }
      }
    end

    def narrative_summary
      {
        commentary: report.commentary,
        additional_activities: report.additional_activities,
        additional_info: report.additional_info
      }
    end

    def bid_items_summary
      report.placed_quantities.includes(:bid_item).map do |pq|
        bid_item = pq.bid_item
        {
          placed_quantity_id: pq.id,
          bid_item_id: bid_item&.id,
          code: bid_item&.code,
          description: bid_item&.description,
          quantity: pq.quantity,
          notes: pq.notes,
          checklist_questions: bid_item&.active_questions || [],
          checklist_answers: pq.checklist_answers || {}
        }
      end.sort_by { |row| [row[:code].to_s, row[:bid_item_id].to_i, row[:placed_quantity_id].to_i] }
    end

    def qa_entries_summary
      report.qa_entries.map do |qa|
        {
          id: qa.id,
          qa_type: qa.qa_type,
          location: qa.location,
          result: qa.result,
          remarks: qa.remarks
        }
      end.sort_by { |row| row[:id].to_i }
    end

    def workforce_summary
      report.crew_entries.map do |crew|
        {
          id: crew.id,
          contractor: crew.contractor,
          superintendent_count: crew.superintendent_count,
          foreman_count: crew.foreman_count,
          survey_count: crew.survey_count,
          operator_count: crew.operator_count,
          laborer_count: crew.laborer_count,
          electrician_count: crew.electrician_count,
          notes: crew.notes
        }
      end.sort_by { |row| row[:id].to_i }
    end

    def equipment_summary
      report.equipment_entries.map do |equipment|
        {
          id: equipment.id,
          contractor: equipment.contractor,
          make_model: equipment.make_model,
          quantity: equipment.quantity,
          hours: equipment.hours,
          remarks: equipment.remarks
        }
      end.sort_by { |row| row[:id].to_i }
    end

    def spec_checklists_summary
      report.checklist_entries.includes(:spec_item).map do |entry|
        spec = entry.spec_item
        {
          checklist_entry_id: entry.id,
          spec_item_id: spec&.id,
          code: spec&.code,
          description: spec&.description,
          division: spec&.division,
          checklist_questions: spec&.normalized_questions || [],
          checklist_answers: entry.checklist_answers || {}
        }
      end.sort_by { |row| [row[:code].to_s, row[:spec_item_id].to_i, row[:checklist_entry_id].to_i] }
    end

    def attachments_summary
      report.report_attachments.map do |attachment|
        file = attachment.file
        blob = file.attached? ? file.blob : nil
        {
          id: attachment.id,
          caption: attachment.caption,
          filename: blob&.filename&.to_s,
          content_type: blob&.content_type,
          byte_size: blob&.byte_size,
          created_at: attachment.created_at&.iso8601
        }
      end.sort_by { |row| row[:id].to_i }
    end

    def photo_slots
      report.report_attachments
            .select { |attachment| image_attachment?(attachment) }
            .first(PHOTO_SLOT_COUNT)
            .map do |attachment|
              file = attachment.file
              blob = file.attached? ? file.blob : nil
              {
                attachment_id: attachment.id,
                caption: attachment.caption,
                filename: blob&.filename&.to_s,
                content_type: blob&.content_type,
                byte_size: blob&.byte_size
              }
            end
    end

    def image_attachment?(attachment)
      return false unless attachment.file.attached?

      blob = attachment.file.blob
      return false unless blob

      blob.content_type&.start_with?("image/") || attachment.file.representable?
    end

    def format_date(date)
      date&.strftime("%Y-%m-%d")
    end
  end
end
