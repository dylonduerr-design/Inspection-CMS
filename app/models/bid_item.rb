class BidItem < ApplicationRecord
  # --- 1. ASSOCIATIONS ---
  # The Bid Item belongs to the "Container" (Project) 
  # and acts as a translator for the "Definition" (Spec Item)
  belongs_to :project
  belongs_to :spec_item 
  
  has_many :placed_quantities, dependent: :restrict_with_error
  
  # --- 2. VALIDATIONS ---
  validates :code, presence: true
  validates :bid_quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  # MAESTRO: This ensures a code (e.g. "P-401") is unique ONLY within this specific project.
  # This allows Project A and Project B to both have an item called "P-401".
  validates :code, uniqueness: { scope: :project_id, message: "already exists in this project" }
  
  validate :checklist_questions_must_be_array

  # --- 3. THE "TRAFFIC COP" (Smart Logic) ---
  # This determines which questions appear in the form
  # Returns array of question objects with shape:
  # { id:, prompt:, kind:, options:, placeholder:, help_text:, required:, default_value:, validation: }
  def active_questions
    # A. If Bid Item has specific overrides, use them
    questions = checklist_questions.presence || []
    return normalize_questions(questions) if questions.any?
    
    # B. Otherwise, fallback to the Spec's questions
    spec_questions = spec_item&.checklist_questions.presence || []
    return normalize_questions(spec_questions) if spec_questions.any?
    
    # C. Default to empty
    []
  end

  # --- 4. VIRTUAL ATTRIBUTES (For the Form) ---
  # GETTER: Returns text for the textarea (extracts prompts from objects)
  def questions_text
    active_questions.map { |q| q.is_a?(Hash) ? q["prompt"] : q }.join("\n")
  end

  # SETTER: Saves text as array of question objects
  def questions_text=(text)
    prompts = text.to_s.split("\n").map(&:strip).reject(&:blank?)
    self.checklist_questions = prompts.each_with_index.map do |prompt, idx|
      {
        "id" => generate_question_id(prompt, idx),
        "prompt" => prompt,
        "kind" => "radio",
        "options" => ["Yes", "No", "N/A"],
        "required" => false
      }
    end
  end

  private

  # Normalize questions to ensure they're all objects (handles legacy string arrays)
  def normalize_questions(questions)
    return [] unless questions.is_a?(Array)
    
    questions.each_with_index.map do |q, idx|
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

  def generate_question_id(prompt, index)
    base = prompt.to_s.downcase.gsub(/[^a-z0-9\s]/, '').gsub(/\s+/, '_')
    "#{base}_#{index + 1}"
  end

  def checklist_questions_must_be_array
    if checklist_questions.present? && !checklist_questions.is_a?(Array)
      errors.add(:checklist_questions, "must be a list of questions")
    end
  end
end