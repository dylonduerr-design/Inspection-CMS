module Api
  module V1
    class WeeklyReportsController < Api::BaseController
      before_action :set_weekly_report, only: %i[show update generate ai_status]

      # GET /api/v1/weekly_reports
      def index
        scope = WeeklyReport.includes(:project, :user).order(end_date: :desc)
        scope = scope.where(project_id: params[:project_id]) if params[:project_id].present?
        scope = scope.limit(params[:limit] || 20)

        render json: scope.map { |wr| weekly_summary(wr) }
      end

      # GET /api/v1/weekly_reports/:id
      def show
        render json: weekly_detail(@weekly_report)
      end

      # POST /api/v1/weekly_reports
      def create
        wr = current_user.weekly_reports.build(weekly_report_params)
        wr.status = :draft

        if wr.save
          render json: weekly_detail(wr), status: :created
        else
          render json: { errors: wr.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/weekly_reports/:id
      def update
        if @weekly_report.update(weekly_report_update_params)
          render json: weekly_detail(@weekly_report)
        else
          render json: { errors: @weekly_report.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/weekly_reports/:id/generate
      def generate
        unless @weekly_report.ai_can_generate?
          return render json: { error: "Cannot generate for status: #{@weekly_report.status}" }, status: :unprocessable_entity
        end

        service = WeeklyReportService.new(@weekly_report)
        service.aggregate!
        @weekly_report.update!(ai_status: "queued")

        intents = %w[weekly_weather weekly_work_summary weekly_lab_testing weekly_materials weekly_problem_areas]
        intents.each do |intent|
          WeeklyReportAiGenerateJob.perform_later(@weekly_report.id, intent)
        end

        render json: { status: "queued", weekly_report_id: @weekly_report.id }
      end

      # GET /api/v1/weekly_reports/:id/ai_status
      def ai_status
        render json: {
          ai_status: @weekly_report.ai_status,
          ai_error: @weekly_report.ai_error,
          sections: {
            weather_summary: @weekly_report.weather_summary,
            work_summary: @weekly_report.work_summary,
            lab_testing_summary: @weekly_report.lab_testing_summary,
            materials_summary: @weekly_report.materials_summary,
            problem_areas: @weekly_report.problem_areas
          }
        }
      end

      private

      def set_weekly_report
        @weekly_report = WeeklyReport.find(params[:id])
      end

      def weekly_report_params
        params.require(:weekly_report).permit(:project_id, :start_date, :end_date)
      end

      def weekly_report_update_params
        params.require(:weekly_report).permit(
          :weather_summary, :work_summary, :lab_testing_summary,
          :materials_summary, :problem_areas, :status
        )
      end

      def weekly_summary(wr)
        {
          id: wr.id,
          project: wr.project&.name,
          project_id: wr.project_id,
          report_number: wr.report_number,
          start_date: wr.start_date,
          end_date: wr.end_date,
          status: wr.status,
          ai_status: wr.ai_status
        }
      end

      def weekly_detail(wr)
        weekly_summary(wr).merge(
          weather_summary: wr.weather_summary,
          work_summary: wr.work_summary,
          lab_testing_summary: wr.lab_testing_summary,
          materials_summary: wr.materials_summary,
          problem_areas: wr.problem_areas,
          weather_data: wr.weather_data_json,
          completion_data: wr.completion_data_json,
          contract_time: wr.contract_time,
          days_charged: wr.days_charged,
          last_working_day: wr.last_working_day_formatted
        )
      end
    end
  end
end
