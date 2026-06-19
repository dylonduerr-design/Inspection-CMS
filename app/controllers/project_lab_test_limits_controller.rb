class ProjectLabTestLimitsController < ApplicationController
  before_action :set_project
  before_action :require_qc!

  def update
    ActiveRecord::Base.transaction do
      ProjectLabTestLimit::DEFINITIONS.each do |definition|
        key = ProjectLabTestLimit.key_for(definition[:spec_code], definition[:parameter])
        attrs = limit_params.fetch(key, {})
        lower_limit = decimal_or_nil(attrs[:lower_limit])
        upper_limit = decimal_or_nil(attrs[:upper_limit])

        record = @project.project_lab_test_limits.find_or_initialize_by(
          spec_code: definition[:spec_code],
          parameter: definition[:parameter]
        )

        if lower_limit.nil? && upper_limit.nil?
          record.destroy! if record.persisted?
        else
          record.update!(lower_limit: lower_limit, upper_limit: upper_limit)
        end
      end
    end

    refresh_lab_test_results
    enqueue_pwl_recalculation
    redirect_to project_path(@project, anchor: "lab-tests"), notice: "Lab test limits updated.", status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    redirect_to project_path(@project, anchor: "lab-tests"), alert: e.record.errors.full_messages.to_sentence, status: :see_other
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def limit_params
    params.fetch(:limits, {}).permit!
  end

  def decimal_or_nil(value)
    return nil if value.blank?

    BigDecimal(value.to_s)
  rescue ArgumentError
    nil
  end

  def enqueue_pwl_recalculation
    @project.asphalt_lots.for_mix("P-401").pluck(:id).each do |lot_id|
      PwlRecalculationJob.perform_later(lot_id)
    end
  end

  def refresh_lab_test_results
    @project.lab_test_results
            .where(spec_code: "P-401", result_kind: [
              LabTestResult::RESULT_KIND_HMA_AIR_VOIDS,
              LabTestResult::RESULT_KIND_CORE_COMPACTION
            ])
            .find_each(&:refresh_project_limit_result!)
  end

  def require_qc!
    return if current_user&.can_qc?

    redirect_to project_path(@project, anchor: "lab-tests"), alert: "You are not authorized to modify lab test limits."
  end
end
