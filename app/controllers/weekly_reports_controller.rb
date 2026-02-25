class WeeklyReportsController < ApplicationController
  before_action :set_weekly_report, only: %i[show edit update destroy generate export ai_status]

  # GET /weekly_reports
  def index
    @projects = Project.order(:name)
    @selected_project_id = params[:project_id]
    @project = Project.find_by(id: @selected_project_id)

    weekly_reports_scope = WeeklyReport.includes(:project, :user).order(end_date: :desc)
    weekly_reports_scope = weekly_reports_scope.where(project_id: @selected_project_id) if @selected_project_id.present?
    @weekly_reports = weekly_reports_scope

    @week_options = build_week_options

    # Determine the selected week ending date (always a Friday)
    selected_week = parse_week_ending(params[:week_ending])
    available_week_endings = @week_options.map { |option| option[1] }
    @week_ending = if selected_week.present? && available_week_endings.include?(selected_week.to_s)
                     selected_week
                   elsif available_week_endings.include?(most_recent_friday.to_s)
                     most_recent_friday
                   elsif available_week_endings.any?
                     Date.parse(available_week_endings.last)
                   else
                     most_recent_friday
                   end

    @week_start = @week_ending - 6  # Saturday through Friday (7-day period)

    # Compute week number from project start or just sequential
    @week_number = compute_week_number(@week_ending)

    # Check if a weekly report already exists for this week + project
    if @project
      @existing_weekly_report = WeeklyReport.find_by(project: @project, end_date: @week_ending)
    end

    # Load daily reports for the selected week (finalized / authorized)
    reports_scope = Report.includes(:user, :project, :phase)
                          .where(start_date: @week_start..@week_ending)
                          .order(start_date: :desc)

    reports_scope = reports_scope.where(project_id: @selected_project_id) if @selected_project_id.present?

    # Show finalized reports (the ones that feed into weekly reports)
    @reports = reports_scope.where(status: :finalize)
  end

  # POST /weekly_reports
  def create
    @weekly_report = current_user.weekly_reports.build(weekly_report_params)

    if @weekly_report.save
      # Run aggregation to compute weather data and completion percentages
      WeeklyReportService.new(@weekly_report).aggregate!
      redirect_to @weekly_report, notice: "Weekly report created. Review the sections and generate AI summaries."
    else
      redirect_to weekly_reports_path(
        project_id: params.dig(:weekly_report, :project_id),
        week_ending: params.dig(:weekly_report, :end_date)
      ), alert: @weekly_report.errors.full_messages.join(", ")
    end
  end

  # GET /weekly_reports/:id
  def show
  end

  # GET /weekly_reports/:id/edit
  def edit
  end

  # PATCH /weekly_reports/:id
  def update
    if @weekly_report.update(weekly_report_edit_params)
      redirect_to @weekly_report, notice: "Weekly report updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /weekly_reports/:id
  def destroy
    @weekly_report.destroy
    redirect_to weekly_reports_path(project_id: @weekly_report.project_id), notice: "Weekly report deleted."
  end

  # POST /weekly_reports/:id/generate
  # Re-runs aggregation and triggers AI generation
  def generate
    service = WeeklyReportService.new(@weekly_report)
    service.aggregate!

    # Queue AI generation for all 5 narrative sections
    @weekly_report.update_columns(ai_status: 'queued', ai_error: nil)

    WeeklyReportAiGenerateJob::INTENT_FIELD_MAP.each_key do |intent|
      WeeklyReportAiGenerateJob.perform_later(@weekly_report.id, intent, current_user.id)
    end

    redirect_to @weekly_report, notice: "Data aggregated and AI generation queued. Sections will populate automatically."
  end

  # GET /weekly_reports/:id/ai_status
  def ai_status
    render json: {
      ai_status: @weekly_report.ai_status,
      ai_error: @weekly_report.ai_error,
      status: @weekly_report.status,
      sections: {
        weather_summary: @weekly_report.weather_summary.present?,
        work_summary: @weekly_report.work_summary.present?,
        lab_testing_summary: @weekly_report.lab_testing_summary.present?,
        materials_summary: @weekly_report.materials_summary.present?,
        problem_areas: @weekly_report.problem_areas.present?
      }
    }
  end

  # POST /weekly_reports/:id/export
  def export
    begin
      output_file = WeeklyReportExporter.generate(@weekly_report)
      filename = "FAA_Weekly_#{@weekly_report.project&.contract_number}_#{@weekly_report.end_date.strftime('%Y-%m-%d')}.docx"

      send_file output_file.path,
                filename: filename,
                type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                disposition: 'attachment'
    rescue => e
      redirect_to @weekly_report, alert: "Export failed: #{e.message}"
    end
  end

  private

  def set_weekly_report
    @weekly_report = WeeklyReport.find(params[:id])
  end

  def weekly_report_params
    params.require(:weekly_report).permit(:project_id, :start_date, :end_date)
  end

  def weekly_report_edit_params
    params.require(:weekly_report).permit(
      :weather_summary, :work_summary, :lab_testing_summary,
      :materials_summary, :problem_areas, :status
    )
  end

  def most_recent_friday
    today = Date.current
    days_since_friday = (today.wday - 5) % 7
    days_since_friday = 7 if days_since_friday == 0
    today - days_since_friday
  end

  def parse_week_ending(value)
    return nil if value.blank?

    parsed = Date.parse(value)
    # Normalize to Friday for consistency
    parsed + ((5 - parsed.wday) % 7)
  rescue ArgumentError
    nil
  end

  def build_week_options
    end_friday = most_recent_friday

    start_anchor = if @project&.contract_start_date.present?
                     @project.contract_start_date
                   elsif @selected_project_id.present?
                     Report.where(project_id: @selected_project_id).minimum(:start_date)
                   else
                     Report.minimum(:start_date)
                   end

    start_anchor ||= end_friday - 26.weeks

    first_friday = start_anchor + ((5 - start_anchor.wday) % 7)
    return [] if first_friday > end_friday

    options = []
    current_friday = first_friday

    while current_friday <= end_friday
      week_number = compute_week_number(current_friday)
      label = "Week #{week_number}: #{current_friday.strftime('%A, %m/%d/%Y')}"
      options << [label, current_friday.to_s]
      current_friday += 7
    end

    options
  end

  def compute_week_number(friday_date)
    return 1 unless @project&.contract_start_date

    weeks = ((friday_date - @project.contract_start_date).to_f / 7).ceil
    [weeks, 1].max
  end
end
