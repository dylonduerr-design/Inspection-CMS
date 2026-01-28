require 'csv'
require 'tempfile'

class ReportsController < ApplicationController
  include Pagy::Backend
  
  before_action :set_report, only: %i[ show start_export ai_payload ]
  before_action :set_report_for_editing, only: %i[ edit update destroy submit_for_qc ]
  before_action :set_report_for_ai_generation, only: %i[ generate_work_summary generate_commentary ai_status ]
  before_action :set_report_for_qc, only: %i[ approve request_revision ]

  def index
    params[:tab] ||= 'reports'
    if params[:tab] == 'reports' && params[:status].blank?
      params[:status] = current_user.qc? ? 'review' : 'in_progress'
    end

    if params[:tab] == 'data'
      build_data_view
      respond_to do |format|
        format.html
      end
      return
    end

    @reports = current_user.qc? ? Report.all : current_user.reports

    @reports = @reports.includes(:user, :project, :phase, :placed_quantities)

    @reports = @reports.where(status: params[:status]) unless params[:status] == 'all'

    if current_user.qc? && params[:status] == 'review'
      @reports = @reports.where.not(user_id: current_user.id)
    end

    apply_search_filters
    
    # Order by relevance if searching, otherwise by date
    if params[:search_text].present?
      @reports = @reports.order(Arel.sql('search_rank DESC NULLS LAST, start_date DESC'))
    else
      @reports = @reports.order(start_date: :desc)
    end
    
    # Paginate results
    @pagy, @reports = pagy(@reports)

    respond_to do |format|
      format.html
      format.csv { send_data generate_csv(@reports), filename: "Project_Master_Log_#{Date.today}.csv" }
    end
  end

  def show
  end

  def new
    @report = current_user.reports.build(status: :in_progress)
    
    if params[:project_id].present?
      @project = Project.find_by(id: params[:project_id])
      
      if @project
        @report.project = @project
        
        @report.contractor = @project.prime_contractor if @project.prime_contractor.present?
      end
    end

    @report.placed_quantities.build
    @report.equipment_entries.build
    @report.crew_entries.build
    
  end

  def edit
    @report.placed_quantities.build if @report.placed_quantities.empty?
    @report.equipment_entries.build if @report.equipment_entries.empty?
    @report.crew_entries.build if @report.crew_entries.empty?
  end

  def create
    @report = current_user.reports.build(report_params)
    @report.status = :in_progress

    if @report.save
      redirect_to report_url(@report), notice: "Report was successfully created."
    else
      @project = @report.project 

      # Ensure nested sections render with at least one row on validation errors.
      @report.placed_quantities.build if @report.placed_quantities.empty?
      @report.equipment_entries.build if @report.equipment_entries.empty?
      @report.crew_entries.build if @report.crew_entries.empty?

      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @report.update(report_params)
      redirect_to report_url(@report), notice: "Report was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @report.destroy!
    redirect_to reports_url, notice: "Report was successfully deleted."
  end


  def submit_for_qc
    unless @report.in_progress? || @report.revise?
      redirect_to @report, alert: "This report can't be submitted from its current status."
      return
    end

    ActiveRecord::Base.transaction do
      @report.update!(status: :review)
      @report.audit_logs.create!(user: current_user, note: "Report submitted for review")
    end

    redirect_to reports_path, notice: "Report submitted for review."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @report, alert: e.record.errors.full_messages.to_sentence
  end

  def approve
    unless @report.review?
      redirect_to @report, alert: "Only reports in Review can be approved."
      return
    end

    ActiveRecord::Base.transaction do
      @report.update!(status: :finalize, result: :pass)
      @report.audit_logs.create!(user: current_user, note: "Report approved and finalized")
    end

    redirect_to @report, notice: "Report approved and finalized."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @report, alert: e.record.errors.full_messages.to_sentence
  end

  def request_revision
    unless @report.review?
      redirect_to @report, alert: "Only reports in Review can be returned for revision."
      return
    end

    note = params[:note].to_s.strip
    if note.blank?
      @revision_note = note
      flash.now[:alert] = "A revision note is required."
      render :show, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      @report.update!(status: :revise, result: :fail)
      @report.audit_logs.create!(user: current_user, note: note)
    end

    redirect_to @report, alert: "Report returned for revision."
  rescue ActiveRecord::RecordInvalid => e
    @revision_note = note
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :show, status: :unprocessable_entity
  end

  # Async export with progress tracking
  def start_export
    export = ReportExport.create!(
      report: @report,
      user: current_user,
      status: 'queued',
      progress: 0
    )
    
    # Enqueue background job
    ReportExportJob.perform_later(export.id)
    
    render json: {
      export_id: export.id,
      status: 'queued',
      progress: 0
    }
  end

  # Testing endpoint: returns normalized AI payload JSON
  def ai_payload
    render json: ReportAi::PayloadBuilder.build(@report)
  end

  # AI Generation Endpoints

  # POST /reports/:id/generate_work_summary
  def generate_work_summary
    if @report.ai_generating?
      render json: { error: 'AI generation already in progress' }, status: :conflict
      return
    end

    @report.enqueue_ai_generation!(intent: :work_summary, user: current_user)

    render json: {
      status: 'queued',
      message: 'Work summary generation started'
    }
  rescue => e
    Rails.logger.error("[ReportsController#generate_work_summary] Error: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /reports/:id/generate_commentary
  def generate_commentary
    if @report.ai_generating?
      render json: { error: 'AI generation already in progress' }, status: :conflict
      return
    end

    @report.enqueue_ai_generation!(intent: :commentary, user: current_user)

    render json: {
      status: 'queued',
      message: 'Commentary generation started'
    }
  rescue => e
    Rails.logger.error("[ReportsController#generate_commentary] Error: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /reports/:id/ai_status
  def ai_status
    render json: {
      status: @report.ai_status,
      ai_work_summary: @report.ai_work_summary,
      ai_generated_commentary: @report.ai_generated_commentary,
      ai_generated_at: @report.ai_generated_at&.iso8601,
      ai_error: @report.ai_error
    }
  end

  private

    def build_data_view
      project_filter = params[:project_id].presence

      bid_items_scope = BidItem.includes(:project)
      bid_items_scope = bid_items_scope.where(project_id: project_filter) if project_filter

      placed_scope = PlacedQuantity.joins(:report)
                                   .where(reports: { status: Report.statuses[:finalize] })
      placed_scope = placed_scope.where(reports: { project_id: project_filter }) if project_filter

      quantity_sums = placed_scope.group(:bid_item_id).sum(:quantity)

      @bid_item_progress = bid_items_scope.map do |bid_item|
        placed = quantity_sums[bid_item.id].to_f
        target = bid_item.bid_quantity.to_f if bid_item.bid_quantity.present?
        percent = if target && target.positive?
                    ((placed / target) * 100.0).round(1)
                  else
                    nil
                  end

        {
          bid_item: bid_item,
          placed: placed,
          target: target,
          percent: percent
        }
      end
    end

    def set_report
      @report = current_user.qc? ? Report.find(params[:id]) : current_user.reports.find(params[:id])
    end

    def set_report_for_editing
      @report = current_user.reports.find(params[:id])

      return if @report.in_progress? || @report.revise?

      redirect_to @report, alert: "This report can't be edited in its current status."
      return
    end

    # AI generation is owner-only and status-gated (same as editing)
    def set_report_for_ai_generation
      @report = current_user.reports.find(params[:id])

      unless @report.ai_generation_allowed_by?(current_user)
        render json: { error: "AI generation not allowed for this report" }, status: :forbidden
        return
      end
    end

    def set_report_for_qc
      unless current_user.qc?
        raise ActiveRecord::RecordNotFound
      end

      @report = Report.find(params[:id])

      if @report.user_id == current_user.id
        raise ActiveRecord::RecordNotFound
      end
    end

    def apply_search_filters
      @reports = @reports.filter_by_inspector(params[:inspector]) if params[:inspector].present?
      @reports = @reports.filter_by_text(params[:search_text]) if params[:search_text].present?
      @reports = @reports.filter_by_project(params[:project_id]) if params[:project_id].present?

      @reports = @reports.filter_by_phase(params[:phase_id]) if params[:phase_id].present?
      @reports = @reports.filter_by_has_quantities(params[:has_quantities]) if params[:has_quantities].present?

      @reports = @reports.filter_by_spec_division(params[:spec_division]) if params[:spec_division].present?
      @reports = @reports.filter_by_spec_item(params[:spec_item_id]) if params[:spec_item_id].present?

      @reports = @reports.filter_by_bid_item(params[:bid_item_id]) if params[:bid_item_id].present?

      if params[:precip_min].present?
         max = params[:precip_max].presence || 100 
         @reports = @reports.filter_by_precip_range(params[:precip_min], max)
      end

      if params[:start_date].present?
        end_date = params[:end_date].presence || params[:start_date]
        @reports = @reports.filter_by_date_range(params[:start_date], end_date) 
      end

      if params[:result].present?
        if params[:result] == 'pending'
          @reports = @reports.where(result: [nil, Report.results[:pending]])
        else
          @reports = @reports.where(result: params[:result])
        end
      end
    end

    def generate_csv(reports)
      CSV.generate(headers: true) do |csv|
        csv << [
          "IDR #", "Start Date", "End Date", "Inspector", "Project", "Phase", "Status", 
          "Shift", "Temps (1/2/3)", "Winds (1/2/3)", "Contractor",
          "Item Code", "Item Description", "Quantity", "Unit", "Location", "Notes"
        ]
        
        reports.each do |report|
          inspector_name = report.user&.email || "Unknown"
          temps = [report.temp_1, report.temp_2, report.temp_3].compact.join("/")
          winds = [report.wind_1, report.wind_2, report.wind_3].compact.join("/")

          if report.placed_quantities.empty?
            csv << [
              report.dir_number, report.start_date, report.end_date, inspector_name, report.project&.name, report.phase&.name, report.status_label,
              "#{report.shift_start}-#{report.shift_end}", temps, winds, report.contractor,
              "---", "No Activity", 0, "---", "---", report.commentary
            ]
          else
            report.placed_quantities.each do |entry|
              csv << [
                report.dir_number, report.start_date, report.end_date, inspector_name, report.project&.name, report.phase&.name, report.status_label,
                "#{report.shift_start}-#{report.shift_end}", temps, winds, report.contractor,
                entry.bid_item&.code, entry.bid_item&.description, entry.quantity, entry.bid_item&.unit, entry.location, entry.notes
              ]
            end
          end
        end
      end
    end

    def report_params
      params.require(:report).permit(
        :start_date, :end_date,
        :dir_number, :project_id, :phase_id, 
        :shift_start, :shift_end,
        :contract_day,
        :contractor,
        :prime_contractor,

        :temp_1, :temp_2, :temp_3,
        :wind_1, :wind_2, :wind_3,
        :precip_1, :precip_2, :precip_3,
        :weather_summary_1, :weather_summary_2, :weather_summary_3,
        :weather, :temperature,
        :visibility_1, :visibility_2, :visibility_3,
        :surface_conditions,
        :notable_weather_events,

        :station_start, :station_end, :plan_sheet, :relevant_docs,
        
        :deficiency_status, :deficiency_desc,
        :safety_incident, :safety_desc,
        :commentary,
        :traffic_control, :traffic_control_note,
        :environmental, :environmental_note,
        :security, :security_note,
        :air_ops_coordination, :air_ops_note,
        :swppp_controls, :swppp_note,
        :phasing_compliance, :phasing_compliance_note,

        :additional_activities, :additional_info,
        
        # AI generated fields (editable by inspector)
        :ai_work_summary, :ai_generated_commentary,
        
        report_attachments_attributes: [:id, :caption, :file, :_destroy],

        crew_entries_attributes: [
          :id, :contractor,
          :superintendent_count, :foreman_count,
          :survey_count, :operator_count, :laborer_count, :electrician_count, 
          :notes, :_destroy
        ],
        equipment_entries_attributes: [
          :id, :make_model, :hours, :quantity, :contractor, :_destroy
        ],
        placed_quantities_attributes: [
          :id, :bid_item_id, :quantity, :location, :notes, :_destroy, 
          :checklist_answers 
        ],
        
        checklist_entries_attributes: [:id, :spec_item_id, :_destroy, checklist_answers: {}],

        qa_entries_attributes: [
          :id, :qa_type, :location, :result, :remarks, :_destroy
        ]
      )
    end
end
