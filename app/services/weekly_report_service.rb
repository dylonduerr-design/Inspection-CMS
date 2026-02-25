class WeeklyReportService
  attr_reader :weekly_report, :project

  def initialize(weekly_report)
    @weekly_report = weekly_report
    @project = weekly_report.project
  end

  # Main entry point — computes all aggregated data and saves to the record.
  # Does NOT run AI generation (that's a separate async job).
  def aggregate!
    compute_weather_data
    compute_completion_data
    weekly_report.save!
    weekly_report
  end

  # ─── Section 2: Weather ────────────────────────────────────────────

  def compute_weather_data
    reports = authorized_reports_in_period.where.not(temp_1: [nil, ""])

    temps = []
    winds = []
    precips = []
    events = []

    reports.find_each do |report|
      [report.temp_1, report.temp_2, report.temp_3].each do |t|
        temps << parse_numeric(t) if t.present?
      end
      [report.wind_1, report.wind_2, report.wind_3].each do |w|
        winds << parse_numeric(w) if w.present?
      end
      [report.precip_1, report.precip_2, report.precip_3].each do |p|
        precips << parse_numeric(p) if p.present?
      end
      events << report.notable_weather_events if report.notable_weather_events.present?
    end

    weather_data = {
      temp_high: temps.any? ? temps.max : nil,
      temp_low: temps.any? ? temps.min : nil,
      temp_avg: temps.any? ? (temps.sum / temps.size).round(1) : nil,
      wind_avg: winds.any? ? (winds.sum / winds.size).round(1) : nil,
      wind_max: winds.any? ? winds.max : nil,
      precip_total: precips.any? ? precips.sum.round(2) : 0.0,
      notable_events: events.uniq,
      report_count: reports.count
    }

    weekly_report.weather_data_json = weather_data
  end

  # ─── Section 3: Completion % by Category ───────────────────────────

  def compute_completion_data
    bid_items = BidItem.includes(:spec_item).where(project: project)

    # Sum placed quantities from finalized reports (matching data view logic)
    placed_by_bid_item = PlacedQuantity.joins(:report)
                                        .where(reports: { status: Report.statuses[:finalize], project_id: project.id })
                                        .group(:bid_item_id)
                                        .sum(:quantity)

    category_totals = Hash.new { |h, k| h[k] = { placed: 0.0, target: 0.0 } }
    total_placed = 0.0
    total_target = 0.0

    bid_items.find_each do |bi|
      target = bi.bid_quantity.to_f
      next if target <= 0

      placed = placed_by_bid_item[bi.id].to_f
      category = bi.spec_item&.division.presence || "Uncategorized"

      category_totals[category][:placed] += placed
      category_totals[category][:target] += target
      total_placed += placed
      total_target += target
    end

    overall_pct = total_target.positive? ? ((total_placed / total_target) * 100.0).round(1) : 0.0

    categories = category_totals.map do |name, totals|
      pct = totals[:target].positive? ? ((totals[:placed] / totals[:target]) * 100.0).round(1) : 0.0
      { name: name, percent: pct, placed: totals[:placed].round(3), target: totals[:target].round(3) }
    end.sort_by { |c| c[:name] }

    weekly_report.completion_data_json = {
      overall_percent: overall_pct,
      categories: categories,
      computed_at: Time.current.iso8601
    }
  end

  # ─── Payload builders for AI generation ────────────────────────────

  # Section 4: Collect commentary from daily reports for AI
  # Uses human-written commentary and additional activities/info fields.
  MAX_ENTRY_CHARS = 2000
  MAX_ADDITIONAL_CHARS = 500

  def work_summary_payload
    reports = authorized_reports_in_period
    entries = reports.map do |r|
      summary = truncate_text(r.commentary, MAX_ENTRY_CHARS)
      additional = truncate_text(r.additional_activities, MAX_ADDITIONAL_CHARS)
      additional_info = truncate_text(r.additional_info, MAX_ADDITIONAL_CHARS)

      { date: r.start_date.to_s, summary: summary, additional_activities: additional, additional_info: additional_info }
    end.reject { |e| e[:summary].blank? && e[:additional_activities].blank? && e[:additional_info].blank? }

    # Include category names for grouping instructions
    categories = (weekly_report.completion_data_json || {}).dig("categories")&.map { |c| c["name"] } || []

    { daily_entries: entries, categories: categories }
  end

  # Section 5a: Collect QA entries for AI lab testing summary
  def lab_testing_payload
    qa_entries = QaEntry.joins(:report)
                        .where(reports: { project_id: project.id })
                        .where(reports: { start_date: weekly_report.start_date..weekly_report.end_date })
                        .where.not(reports: { authorized_by_id: nil })
                        .includes(:report)

    qa_entries.map do |qa|
      {
        date: qa.report.start_date.to_s,
        test_type: qa.qa_type,
        test_category: qa_type_label(qa.qa_type),
        result: qa.result,
        location: qa.location,
        remarks: qa.remarks
      }
    end
  end

  # Section 5b: Collect failed/OOT QA entries for materials summary
  def materials_payload
    QaEntry.joins(:report)
           .where(reports: { project_id: project.id })
           .where(reports: { start_date: weekly_report.start_date..weekly_report.end_date })
           .where.not(reports: { authorized_by_id: nil })
           .where(result: QaEntry.results[:qa_fail])
           .includes(:report)
           .map do |qa|
      {
        date: qa.report.start_date.to_s,
        test_type: qa.qa_type,
        result: qa.result,
        location: qa.location,
        remarks: qa.remarks
      }
    end
  end

  # Section 7: Collect deficiencies and issues for problem areas
  def problem_areas_payload
    reports = authorized_reports_in_period
    deficiencies = []
    safety_issues = []

    reports.find_each do |r|
      if r.deficiency_status != "no_deficiency" && r.deficiency_desc.present?
        deficiencies << { date: r.start_date.to_s, status: r.deficiency_status, description: r.deficiency_desc }
      end
      if r.safety_incident == "safety_yes" && r.safety_desc.present?
        safety_issues << { date: r.start_date.to_s, description: r.safety_desc }
      end
    end

    { deficiencies: deficiencies, safety_issues: safety_issues }
  end

  # Section 2: Weather data for AI narrative generation
  def weather_payload
    weekly_report.weather_data_json || {}
  end

  private

  # Human-readable labels for QA test types, mapped to FAA bid-item style categories
  QA_TYPE_LABELS = {
    'compaction'       => 'Compaction / Density Testing',
    'concrete_slump'   => 'Concrete Testing (Slump)',
    'concrete_cylinder' => 'Concrete Testing (Cylinder)',
    'asphalt_temp'     => 'Asphalt Mat Temperature',
    'nuclear_gauge'    => 'Nuclear Gauge Density & Moisture',
    'proof_roll'       => 'Proof-Roll Evaluation'
  }.freeze

  def qa_type_label(qa_type)
    QA_TYPE_LABELS.fetch(qa_type.to_s, qa_type.to_s.humanize)
  end

  def truncate_text(text, limit)
    return nil if text.blank?
    return text if text.length <= limit

    text[0, limit] + '…'
  end

  def authorized_reports_in_period
    Report.where(project: project)
          .where.not(authorized_by_id: nil)
          .where(start_date: weekly_report.start_date..weekly_report.end_date)
          .order(:start_date)
  end

  def parse_numeric(value)
    return nil if value.blank?

    # Handle ranges like "65-72" by averaging
    if value.to_s.include?('-') && value.to_s.match?(/\d+-\d+/)
      parts = value.to_s.split('-').map(&:to_f)
      return parts.sum / parts.size
    end

    # Strip non-numeric suffixes (e.g., "72°F" => 72)
    cleaned = value.to_s.gsub(/[^0-9.\-]/, '')
    cleaned.present? ? cleaned.to_f : nil
  end
end
