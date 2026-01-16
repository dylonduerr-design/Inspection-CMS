class PlacedQuantity < ApplicationRecord
  belongs_to :report
  belongs_to :bid_item

  validates :bid_item, presence: true

  # Coerce string JSON to hash before validation
  before_validation :normalize_checklist_answers

  # Validate that checklist_answers is a hash
  validate :checklist_answers_must_be_hash

  # SMART GETTER: Ensures this always returns a Hash/List, never a String
  def checklist_answers
    # 1. Get the raw value from the database
    value = super

    # 2. If it's already a real Hash (Postgres usually does this), return it
    return value if value.is_a?(Hash)

    # 3. If it's a String (SQLite or text column), parse it into a Hash
    if value.is_a?(String) && value.present?
      begin
        return JSON.parse(value)
      rescue JSON::ParserError
        return {} # Fallback if data is corrupted
      end
    end

    # 4. Default to empty hash if nil
    {}
  end

  # Setter to coerce string JSON into hash
  def checklist_answers=(value)
    if value.is_a?(String) && value.present?
      begin
        parsed = JSON.parse(value)
        super(parsed.is_a?(Hash) ? parsed : {})
      rescue JSON::ParserError => e
        Rails.logger.warn("PlacedQuantity: Invalid JSON in checklist_answers: #{e.message}")
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