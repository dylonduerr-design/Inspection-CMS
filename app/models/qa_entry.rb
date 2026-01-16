class QaEntry < ApplicationRecord
  belongs_to :report

  # We use the existing column name 'qa_type' found in your file
  enum qa_type: { 
    compaction: 0, 
    concrete_slump: 1, 
    concrete_cylinder: 2, 
    asphalt_temp: 3, 
    nuclear_gauge: 4,
    proof_roll: 5 
  }

  # These keys (qa_pass, qa_fail) are what we will use in the Report logic
  enum result: { 
    qa_pass: 0, 
    qa_fail: 1, 
    qa_pending: 2, 
    qa_n_a: 3 
  }

  validates :qa_type, presence: true
  validates :result, presence: true
end