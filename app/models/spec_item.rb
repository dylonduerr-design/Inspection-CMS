class SpecItem < ApplicationRecord
  # This Spec governs many Bid Items
  has_many :bid_items
  has_many :checklist_entries
  
  # Validations to keep data clean
  validates :code, presence: true, uniqueness: true

  # Returns normalized questions as array of hashes with indifferent access
  # Each question has shape:
  # { id:, prompt:, kind:, options:, placeholder:, help_text:, required:, default_value:, validation: }
  def normalized_questions
    return [] unless checklist_questions.is_a?(Array)
    
    checklist_questions.each_with_index.map do |q, idx|
      if q.is_a?(Hash)
        q.with_indifferent_access
      else
        # Legacy string format - convert to object
        {
          "id" => generate_question_id(q.to_s, idx),
          "prompt" => q.to_s,
          "kind" => "radio",
          "options" => ["Yes", "No", "N/A"],
          "required" => false
        }.with_indifferent_access
      end
    end
  end

  # Build a question object from parameters (for admin/seed use)
  def self.build_question(prompt:, kind: "radio", options: nil, id: nil, **attrs)
    base_id = id || prompt.to_s.downcase.gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, '_')
    
    question = {
      "id" => base_id,
      "prompt" => prompt,
      "kind" => kind,
      "required" => attrs[:required] || false
    }
    
    # Add options for radio/checkbox types
    if %w[radio checkbox].include?(kind)
      question["options"] = options || ["Yes", "No", "N/A"]
    end
    
    # Add optional fields if provided
    question["placeholder"] = attrs[:placeholder] if attrs[:placeholder]
    question["help_text"] = attrs[:help_text] if attrs[:help_text]
    question["default_value"] = attrs[:default_value] if attrs[:default_value]
    question["validation"] = attrs[:validation] if attrs[:validation]
    
    question
  end

  private

  def generate_question_id(prompt, index)
    base = prompt.to_s.downcase.gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, '_')
    "#{base}_#{index + 1}"
  end
end