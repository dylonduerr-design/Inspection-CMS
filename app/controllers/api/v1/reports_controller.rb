module Api
  module V1
    class ReportsController < Api::BaseController
      before_action :set_report, only: %i[show update generate_work_summary generate_commentary ai_status]

      # GET /api/v1/reports
      def index
        scope = Report.includes(:project, :phase, :user).order(start_date: :desc)
        scope = scope.where(project_id: params[:project_id]) if params[:project_id].present?
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where(start_date: params[:start_date]..params[:end_date]) if params[:start_date].present? && params[:end_date].present?
        scope = scope.limit(params[:limit] || 50)

        render json: scope.map { |r| report_summary(r) }
      end

      # GET /api/v1/reports/:id
      def show
        render json: report_detail(@report)
      end

      # POST /api/v1/reports
      def create
        report = current_user.reports.build(report_params)
        report.status = :in_progress

        if report.save
          render json: report_detail(report), status: :created
        else
          render json: { errors: report.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/reports/:id
      def update
        unless current_user == @report.user || current_user.admin?
          return render json: { error: "Not authorized" }, status: :forbidden
        end
        unless @report.in_progress? || @report.revise?
          return render json: { error: "Report is not editable (status: #{@report.status})" }, status: :unprocessable_entity
        end

        if @report.update(report_params)
          render json: report_detail(@report)
        else
          render json: { errors: @report.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/reports/:id/generate_work_summary
      def generate_work_summary
        unless @report.ai_generation_allowed_by?(current_user)
          return render json: { error: "AI generation not allowed" }, status: :forbidden
        end

        @report.enqueue_ai_generation!(intent: :work_summary, user: current_user)
        render json: { status: "queued", report_id: @report.id }
      end

      # POST /api/v1/reports/:id/generate_commentary
      def generate_commentary
        unless @report.ai_generation_allowed_by?(current_user)
          return render json: { error: "AI generation not allowed" }, status: :forbidden
        end

        @report.enqueue_ai_generation!(intent: :commentary, user: current_user)
        render json: { status: "queued", report_id: @report.id }
      end

      # GET /api/v1/reports/:id/ai_status
      def ai_status
        render json: {
          ai_status: @report.ai_status,
          ai_stage: @report.ai_stage,
          ai_work_summary: @report.ai_work_summary,
          ai_generated_commentary: @report.ai_generated_commentary,
          ai_error: @report.ai_error,
          ai_generated_at: @report.ai_generated_at
        }
      end

      private

      def set_report
        @report = Report.find(params[:id])
      end

      def report_params
        params.require(:report).permit(
          :start_date, :end_date, :dir_number, :project_id, :phase_id,
          :shift_start, :shift_end, :contract_day, :contractor, :prime_contractor,
          :temp_1, :temp_2, :temp_3,
          :wind_1, :wind_2, :wind_3,
          :precip_1, :precip_2, :precip_3,
          :weather_summary_1, :weather_summary_2, :weather_summary_3,
          :visibility_1, :visibility_2, :visibility_3,
          :surface_conditions, :notable_weather_events,
          :station_start, :station_end, :plan_sheet, :relevant_docs,
          :deficiency_status, :deficiency_desc,
          :safety_incident, :safety_desc,
          :commentary, :additional_activities, :additional_info,
          :traffic_control, :traffic_control_note,
          :environmental, :environmental_note,
          :security, :security_note,
          :air_ops_coordination, :air_ops_note,
          :swppp_controls, :swppp_note,
          :phasing_compliance, :phasing_compliance_note,
          :ai_work_summary, :ai_generated_commentary,
          crew_entries_attributes: [
            :id, :contractor,
            :superintendent_count, :foreman_count, :survey_count,
            :operator_count, :laborer_count, :electrician_count, :notes, :_destroy
          ],
          equipment_entries_attributes: [
            :id, :contractor, :make_model, :quantity, :hours, :_destroy
          ],
          placed_quantities_attributes: [
            :id, :bid_item_id, :quantity, :location, :notes, :_destroy
          ],
          qa_entries_attributes: [
            :id, :qa_type, :location, :result, :remarks, :_destroy
          ],
          checklist_entries_attributes: [
            :id, :spec_item_id, :_destroy, checklist_answers: {}
          ]
        )
      end

      def report_summary(r)
        {
          id: r.id,
          dir_number: r.dir_number,
          start_date: r.start_date,
          end_date: r.end_date,
          status: r.status,
          result: r.result,
          project: r.project&.name,
          project_id: r.project_id,
          phase: r.phase&.name,
          phase_id: r.phase_id,
          inspector: r.user&.full_name,
          contract_day: r.contract_day
        }
      end

      def report_detail(r)
        report_summary(r).merge(
          shift_start: r.shift_start,
          shift_end: r.shift_end,
          contractor: r.contractor,
          weather: {
            temp: [r.temp_1, r.temp_2, r.temp_3],
            wind: [r.wind_1, r.wind_2, r.wind_3],
            precip: [r.precip_1, r.precip_2, r.precip_3],
            summary: [r.weather_summary_1, r.weather_summary_2, r.weather_summary_3],
            visibility: [r.visibility_1, r.visibility_2, r.visibility_3],
            surface_conditions: r.surface_conditions,
            notable_events: r.notable_weather_events
          },
          compliance: {
            traffic_control: r.traffic_control, traffic_control_note: r.traffic_control_note,
            environmental: r.environmental, environmental_note: r.environmental_note,
            security: r.security, security_note: r.security_note,
            air_ops_coordination: r.air_ops_coordination, air_ops_note: r.air_ops_note,
            swppp_controls: r.swppp_controls, swppp_note: r.swppp_note,
            phasing_compliance: r.phasing_compliance, phasing_compliance_note: r.phasing_compliance_note
          },
          deficiency: { status: r.deficiency_status, description: r.deficiency_desc },
          safety: { incident: r.safety_incident, description: r.safety_desc },
          narrative: {
            commentary: r.commentary,
            additional_activities: r.additional_activities,
            additional_info: r.additional_info
          },
          ai: {
            work_summary: r.ai_work_summary,
            generated_commentary: r.ai_generated_commentary,
            status: r.ai_status,
            stage: r.ai_stage,
            error: r.ai_error,
            generated_at: r.ai_generated_at
          },
          placed_quantities: r.placed_quantities.includes(bid_item: :spec_item).map { |pq|
            {
              id: pq.id,
              bid_item_id: pq.bid_item_id,
              bid_item_code: pq.bid_item&.code,
              quantity: pq.quantity,
              location: pq.location,
              notes: pq.notes
            }
          },
          crew_entries: r.crew_entries.map { |ce|
            {
              id: ce.id, contractor: ce.contractor,
              superintendent_count: ce.superintendent_count, foreman_count: ce.foreman_count,
              survey_count: ce.survey_count, operator_count: ce.operator_count,
              laborer_count: ce.laborer_count, electrician_count: ce.electrician_count,
              notes: ce.notes
            }
          },
          equipment_entries: r.equipment_entries.map { |ee|
            { id: ee.id, contractor: ee.contractor, make_model: ee.make_model, quantity: ee.quantity, hours: ee.hours }
          },
          qa_entries: r.qa_entries.map { |qa|
            { id: qa.id, qa_type: qa.qa_type, location: qa.location, result: qa.result, remarks: qa.remarks }
          },
          checklist_entries: r.checklist_entries.includes(:spec_item).map { |ce|
            {
              id: ce.id,
              spec_item_id: ce.spec_item_id,
              spec_code: ce.spec_item&.code,
              spec_description: ce.spec_item&.description,
              checklist_answers: ce.checklist_answers
            }
          }
        )
      end
    end
  end
end
