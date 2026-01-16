# app/models/checklist_entry.rb
class ChecklistEntry < ApplicationRecord
  belongs_to :report
  belongs_to :spec_item

  # Coerce string JSON to hash before validation
  before_validation :normalize_checklist_answers

  # Validate that checklist_answers is a hash
  validate :checklist_answers_must_be_hash

  # MAESTRO FIX: Smart getter ensures we never get nil
  def checklist_answers
    # 1. Get raw value
    val = super
    
    # 2. Return immediately if it's already a Hash (Standard behavior)
    return val if val.is_a?(Hash)

    # 3. If it's a JSON string (rare but possible), parse it
    if val.is_a?(String) && val.present?
      begin
        return JSON.parse(val)
      rescue JSON::ParserError
        return {}
      end
    end

    # 4. Fallback to empty hash if nil
    {}
  end

  # Setter to coerce string JSON into hash
  def checklist_answers=(value)
    if value.is_a?(String) && value.present?
      begin
        parsed = JSON.parse(value)
        super(parsed.is_a?(Hash) ? parsed : {})
      rescue JSON::ParserError => e
        Rails.logger.warn("ChecklistEntry: Invalid JSON in checklist_answers: #{e.message}")
        super({})
      end
    else
      super(value)
    end
  end

  private

  def normalize_checklist_answers
    # Ensure checklist_answers is a hash with indifferent access
    if checklist_answers.is_a?(Hash)
      self.checklist_answers = checklist_answers.with_indifferent_access
    end
  end

  def checklist_answers_must_be_hash
    unless checklist_answers.is_a?(Hash)
      errors.add(:checklist_answers, "must be a hash")
    end
  end
end