class SpecItemsController < ApplicationController
  before_action :set_spec_item, only: :update

  def index
    respond_to do |format|
      format.json do
        latest = SpecItem.maximum(:updated_at)
        if stale?(etag: latest, last_modified: latest, public: true)
          json = Rails.cache.fetch("spec_items/all-#{latest.to_i}") do
            SpecItem.order(:division, :code)
                    .as_json(only: %i[id code description division checklist_questions])
                    .to_json
          end
          render json: json
        end
      end
      format.html { redirect_to projects_path(anchor: "spec-checklists") }
    end
  end

  def update
    if @spec_item.update(checklist_questions: normalized_questions_params)
      render json: {
        status: "ok",
        spec_item: @spec_item.slice(:id, :code, :description, :division, :checklist_questions)
      }
    else
      render json: { status: "error", errors: @spec_item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def spec_item_params
    params.require(:spec_item).permit(checklist_questions: [
      :id,
      :prompt,
      :kind,
      :placeholder,
      :help_text,
      :default_value,
      :required,
      { options: [] },
      { validation: %i[min max pattern step] }
    ])
  end

  def normalized_questions_params
    questions = spec_item_params[:checklist_questions]
    return [] unless questions.is_a?(Array)

    bool_cast = ActiveModel::Type::Boolean.new

    questions.map.with_index do |question, idx|
      normalized = question.to_h
      normalized["prompt"] = normalized["prompt"].to_s.strip
      normalized["kind"] = (normalized["kind"].presence || "radio").downcase
      normalized["required"] = bool_cast.cast(normalized["required"])
      if %w[radio checkbox select].include?(normalized["kind"])
        normalized["options"] = Array(normalized["options"]).map(&:to_s).reject(&:blank?)
        normalized["options"] = default_options if normalized["options"].blank?
      else
        normalized.delete("options")
      end
      normalized["placeholder"] = normalized["placeholder"].presence
      normalized["help_text"] = normalized["help_text"].presence
      normalized["default_value"] = normalized["default_value"].presence
      normalized["id"] = normalized["id"].presence || generate_question_id(normalized["prompt"], idx)

      normalized["validation"] = normalize_validation(normalized["validation"])
      normalized
    end
  end

  def normalize_validation(validation_hash)
    return nil unless validation_hash.is_a?(ActionController::Parameters) || validation_hash.is_a?(Hash)

    result = validation_hash.to_h.slice("min", "max", "pattern", "step").each_with_object({}) do |(key, value), acc|
      next if value.blank?

      acc[key] = if key == "pattern"
                   value.to_s
                 else
                   cast_numeric(value)
                 end
    end

    result.presence
  end

  def cast_numeric(val)
    return val if val.is_a?(Numeric)
    Float(val)
  rescue ArgumentError, TypeError
    val
  end

  def default_options
    ["Yes", "No", "N/A"]
  end

  def set_spec_item
    @spec_item = SpecItem.find(params[:id])
  end

  def generate_question_id(prompt, idx)
    base = prompt.to_s.downcase.gsub(/[^a-z0-9\s]/, "").gsub(/\s+/, "_")
    base = "question" if base.blank?
    "#{base}_#{idx + 1}"
  end
end
